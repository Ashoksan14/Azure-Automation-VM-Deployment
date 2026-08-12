# Troubleshooting

## Managed Identity authentication fails

Check that the Automation Account has a system-assigned Managed Identity enabled.

Test:

```powershell
Connect-AzAccount -Identity
Get-AzContext
```

## AuthorizationFailed / insufficient permissions

Grant the Automation Account Managed Identity the required RBAC role on the target resource group. `Contributor` is convenient for labs; use least privilege for production.

## Credential not found

Error example:

```text
Automation Credential 'VM-LocalAdmin' was not found.
```

Create the credential under:

```text
Automation Account -> Shared Resources -> Credentials
```

## Public IP already exists

The runbook checks for `<VMName>-pip` and reuses it when it already exists. This is useful after a partial deployment.

If the existing Public IP is not intended for this VM, remove or rename it before rerunning.

## NIC already exists

The runbook reuses an existing NIC only if it is not attached to a VM. If it is attached, the runbook stops.

## OS disk already exists

The script intentionally stops when `<VMName>-osdisk` already exists. Review whether it belongs to a previous VM or failed deployment before deleting it.

## VM name already exists

Choose a new VM name. The script will not overwrite an existing VM.

## Region mismatch

A NIC must be created in the same region as the VNet. The script checks that `Location` matches the existing VNet location.

## Hotpatch or image errors

The selected image is:

```text
Publisher: MicrosoftWindowsServer
Offer: WindowsServer
SKU: 2022-datacenter-azure-edition-hotpatch
Version: latest
```

Verify the image and selected VM size are available in the target region and meet Hotpatch/Trusted Launch requirements.

## Availability Zone errors

Not every VM size is available in every zone. Try another supported zone or VM size for the selected region.

## Interactive confirmation error

Azure Automation jobs cannot answer interactive prompts. The runbook uses `-Force` where appropriate and checks for existing resources before create/update operations.

## Auto-shutdown problems

Check the `Microsoft.DevTestLab/schedules` resource named:

```text
shutdown-computevm-<VMName>
```

Also verify the timezone and `ShutdownTime` format (`HHmm`, for example `2300`).
