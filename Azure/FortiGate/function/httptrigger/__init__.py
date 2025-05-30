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

# Logger configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Azure Key Vault
KEY_VAULT_NAME = os.environ["AZURE_KEYVAULT_NAME"]
SECRET_NAME = "lwapi-secrets"
FCNAPP_TENANT_NAME = os.environ["FCNAPP_TENANT_NAME"]
TAG_NAME = os.environ["TAG_NAME"]

# URL to get the Bearer Token
AUTH_URL = f"https://{FCNAPP_TENANT_NAME}.lacework.net/api/v2/access/tokens"
CLIENT_ID = os.environ["AZURE_CLIENT_ID"]

credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)

subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
resource_client = ResourceManagementClient(credential, subscription_id)
# Azure Key Vault client
key_vault_uri = f"https://{KEY_VAULT_NAME}.vault.azure.net"
secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)


def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Payload parsing
        body = req.get_json()
        event_id = body.get("event_id")
        
        if not event_id:
            return func.HttpResponse(
                json.dumps({"error": "event_id not found in payload."}),
                status_code=400,
                mimetype="application/json"
            )

        # event_id logging
        logger.info(f"Extracted event_id: {event_id}")

        # getting credentials from Azure Key Vault
        key_id = get_secret("lwapi-secrets")
        uaks_token = get_secret("x-lw-uaks")
        logger.info("Successfully retrieved credentials from Key Vault.")

        # getting Bearer Token
        token = get_bearer_token(key_id, uaks_token)
        logger.info("Successfully obtained Bearer Token.")

        # Create the body for the external API call
        external_api_body = {
            "filters": [{"expression": "eq", "field": "id", "value": event_id}],
            "returns": ["srcEvent"]
        }
        external_api_url = f"https://{FCNAPP_TENANT_NAME}.lacework.net/api/v2/Events/search"
        logger.info(f"Calling event search URL... {external_api_body}")

        # External API call with Bearer Token
        response = requests.post(
            external_api_url,
            json=external_api_body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}"
            }
        )
        response.raise_for_status()

        # Parse the response from the external API
        data = response.json()
        # Needs improvement: Check for valid data and machine_tags
        instance_id = data["data"][0]["srcEvent"]["machine_tags"]["InstanceId"]

        # Log from InstanceId
        logger.info(f"Extracted InstanceId: {instance_id}")

        ## Search for urn

        inventory_api_body = {
            "filters": [{"expression": "eq", "field": "resourceConfig.vmId", "value": instance_id}],
            "returns": ["urn"],
            "csp": "Azure"
        }

        
        inventory_api_url = f"https://{FCNAPP_TENANT_NAME}.lacework.net/api/v2/Inventory/search"
        logger.info(f"Calling inventory search URL with body: {inventory_api_body}")

        # External API call
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

        # Parse the response from the inventory API
        data = response_inv.json()
        urn_instance_id = data["data"][0]["urn"]


        ## End URN search

        # Add the tag "malware=true" to the VM
        add_tag_to_vm(urn_instance_id)

        # Success response
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
    Get Bearer Token from Lacework API using the provided info.
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
    Get a secret from Azure Key Vault.
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
    Function to add a tag "malware=true" to the VM identified by its URN.
    """
    logger.info(f"Starting to add the tag to VM {urn_instance_id}...")


    try:
        
                     
        resource = resource_client.resources.get_by_id(urn_instance_id, api_version="2021-04-01")

        # Keep existing tags or create a new dictionary if none exist
        updated_tags = resource.tags or {}
        updated_tags[TAG_NAME] = "true"

        # Update the resource with the new tags
        resource_client.resources.begin_update_by_id(
            urn_instance_id,
            api_version="2021-04-01",
            parameters={"tags": updated_tags}
        ).result()

        logger.info(f"Tag {TAG_NAME}=true added successfully to {urn_instance_id}")

    except Exception as e:
        logger.error(f"Failed to add tag to resource {urn_instance_id}: {str(e)}")
        raise