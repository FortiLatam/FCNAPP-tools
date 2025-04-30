import json
import logging
import requests
import azure.functions as func
import os
from azure.identity import DefaultAzureCredential 
#from azure.identity import AzureCliCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import TagsResource
from azure.keyvault.secrets import SecretClient
##import azure.mgmt.resource as ResourceManagementClient

# Configuração do logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Nome do segredo no Azure Key Vault
KEY_VAULT_NAME = "fgallego-kv1"
SECRET_NAME = "lwapi-secrets"

# URL para obter o Bearer Token
AUTH_URL = "https://partner-demo.lacework.net/api/v2/access/tokens"
CLIENT_ID = os.environ["AZURE_CLIENT_ID"]

credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)

subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
resource_client = ResourceManagementClient(credential, subscription_id)
# Cliente do Azure Key Vault
key_vault_uri = f"https://{KEY_VAULT_NAME}.vault.azure.net"
secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)


def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Parse do payload recebido
        body = req.get_json()
        event_id = body.get("event_id")
        
        if not event_id:
            return func.HttpResponse(
                json.dumps({"error": "event_id not found in payload."}),
                status_code=400,
                mimetype="application/json"
            )

        # Log do event_id
        logger.info(f"Extracted event_id: {event_id}")

        # Obter credenciais do Azure Key Vault
        key_id = get_secret("lwapi-secrets")
        uaks_token = get_secret("x-lw-uaks")
        logger.info("Successfully retrieved credentials from Key Vault.")

        # Obter o Bearer Token
        token = get_bearer_token(key_id, uaks_token)
        logger.info("Successfully obtained Bearer Token.")

        # Monta o body para a chamada externa
        external_api_body = {
            "filters": [{"expression": "eq", "field": "id", "value": event_id}],
            "returns": ["srcEvent"]
        }
        external_api_url = "https://partner-demo.lacework.net/api/v2/Events/search"
        logger.info(f"Calling event search URL... {external_api_body}")

        # Chamada para a API externa com o Bearer Token
        response = requests.post(
            external_api_url,
            json=external_api_body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}"
            }
        )
        response.raise_for_status()

        # Parse da resposta da API externa
        data = response.json()
        instance_id = data["data"][0]["srcEvent"]["machine_tags"]["InstanceId"]

        # Log do InstanceId
        logger.info(f"Extracted InstanceId: {instance_id}")

        ## Search for urn

        inventory_api_body = {
            "filters": [{"expression": "eq", "field": "resourceConfig.vmId", "value": instance_id}],
            "returns": ["urn"],
            "csp": "Azure"
        }
        inventory_api_url = "https://partner-demo.lacework.net/api/v2/Inventory/search"
        logger.info(f"Calling inventory search URL with body: {inventory_api_body}")

        # Chamada para a API externa com o Bearer Token
        response_inv = requests.post(
            inventory_api_url,
            json=inventory_api_body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}"
            }
        )
        logger.info(f"Response status code: {response_inv.status_code}")
        logger.info(f"Response content: {response_inv.content}")
        response_inv.raise_for_status()

        # Parse da resposta da API externa
        data = response_inv.json()
        urn_instance_id = data["data"][0]["urn"]


        ## End URN search

        # Adiciona a tag "malware=true" (caso use VM no Azure)
        add_tag_to_vm(urn_instance_id)

        # Resposta de sucesso
        return func.HttpResponse(
            json.dumps({"InstanceId": urn_instance_id, "message": "Tag added successfully"}),
            status_code=200,
            mimetype="application/json"
        )

    except json.JSONDecodeError:
        logger.error("Invalid JSON payload.")
        return func.HttpResponse(json.dumps({"error": "Invalid JSON payload."}), status_code=400, mimetype="application/json")
    except requests.exceptions.RequestException as e:
        logger.error(f"Error while calling external API: {str(e)}")
        return func.HttpResponse(json.dumps({"error": "Error while calling external API."}), status_code=500, mimetype="application/json")
    except Exception as e:
        logger.error(f"An unexpected error occurred: {str(e)}")
        return func.HttpResponse(json.dumps({"error": "An unexpected error occurred."}), status_code=500, mimetype="application/json")

def get_bearer_token(key_id, uaks_token):
    """
    Obtém o Bearer Token a partir do endpoint de autenticação.
    """
    try:
        response = requests.post(
            AUTH_URL,
            json={"keyId": key_id},
            headers={"x-lw-uaks": uaks_token, "Content-Type": "application/json"}
        )
        response.raise_for_status()
        token = response.json().get("token")
        if not token:
            raise ValueError("No token in the response.")
        return token
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to obtain Bearer Token: {str(e)}")
        raise
    except ValueError as e:
        logger.error(f"Error in authentication response: {str(e)}")
        raise

def get_secret(secret_name):
    """
    Recupera o segredo do Azure Key Vault.
    """
    try:
        secret = secret_client.get_secret(secret_name)
        logger.info(f"Retrieved secret: {secret_name}")
        if not secret.value:
            raise ValueError(f"Secret {secret_name} is empty.")
        return secret.value
    except Exception as e:
        logger.error(f"Failed to retrieve secret: {str(e)}")
        raise

def add_tag_to_vm(urn_instance_id):
    """
    Função para adicionar a tag "malware=true" a uma VM no Azure.
    """
    logger.info(f"Starting to add the tag to VM {urn_instance_id}...")


    try:
        # Obtém os detalhes do recurso para preservar tags existentes
                     
        resource = resource_client.resources.get_by_id(urn_instance_id, api_version="2021-04-01")

        # Mantém as tags existentes e adiciona a nova tag
        updated_tags = resource.tags or {}
        updated_tags["malware"] = "true"

        # Atualiza as tags do recurso
        resource_client.resources.begin_update_by_id(
            urn_instance_id,
            api_version="2021-04-01",
            parameters={"tags": updated_tags}
        ).result()

        logger.info(f"Tag 'malware=true' added successfully to {urn_instance_id}")

    except Exception as e:
        logger.error(f"Failed to add tag to resource {urn_instance_id}: {str(e)}")
        raise