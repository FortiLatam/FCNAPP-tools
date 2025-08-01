#!/bin/bash

REPORT_FILE="./lacework-scan.json"

    if [ "$SCA_CRIT" == "fail" ]; then
      SCA_CRIT_VULNS=$(jq '[.runs[].tool.driver.rules[] | select((.properties.tags // []) | index("critical") and index("vulnerability"))] | length' $REPORT_FILE)
      echo "Found $SCA_CRIT_VULNS vulnerabilities CRITICAL."

      if [ "$SCA_CRIT_VULNS" -gt 0 ]; then
        echo "❌ Failing pipeline due to $SCA_CRIT_VULNS critical vulnerabilities."
        exit 1
      fi
    fi

    if [ "$SCA_HIGH" == "fail" ]; then
      SCA_HIGH_VULNS=$(jq '[.runs[].tool.driver.rules[] | select((.properties.tags // []) | index("high") and index("vulnerability"))] | length' $REPORT_FILE)
      echo "Found $SCA_HIGH_VULNS vulnerabilities HIGH."

      if [ "$SCA_HIGH_VULNS" -gt 0 ]; then
        echo "❌ Failing pipeline due to $SCA_CRIT_VULNS high vulnerabilities."
        exit 1
      fi
    fi

    if [ "$SAST_CRIT" == "fail" ]; then
      SAST_CRIT_VULNS=$(jq '[.runs[].tool.driver.rules[] | select((.properties.tags // []) | index("critical") and index("weakness"))] | length' $REPORT_FILE)
      echo "Found $SAST_CRIT_VULNS weakness CRITICAL."

      if [ "$SAST_CRIT_VULNS" -gt 0 ]; then
        echo "❌ Failing pipeline due to $SAST_CRIT_VULNS critical weakness."
        exit 1
      fi
    fi

    if [ "$SAST_HIGH" == "fail" ]; then
      SAST_HIGH_VULNS=$(jq '[.runs[].tool.driver.rules[] | select((.properties.tags // []) | index("high") and index("weakness"))] | length' $REPORT_FILE)
      echo "Found $SAST_HIGH_VULNS weakness HIGH."

      if [ "$SAST_HIGH_VULNS" -gt 0 ]; then
        echo "❌ Failing pipeline due to $SAST_HIGH_VULNS high weakness."
        exit 1
      fi
    else
      echo "✅ No fail criteria matched."
    fi

    

