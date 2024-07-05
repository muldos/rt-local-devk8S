# Seperated values file to keep licenses outstide main configuration.
# Ideally for prod setup, this would be passed as a secret or managed with the API
artifactory:
  artifactory:
    license:
        # For multiple licenses (Artifactory enterprise HA), each license
        # needs a block of its own. Separated by a new line as shown by the value of licenseKey below
      licenseKey: |
        YourLicensesHereSeperatedWithNewLinesChangeme==
  