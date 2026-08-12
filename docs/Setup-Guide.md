# Setup Guide

## 1. Create the shared infrastructure

Create a resource group, for example:

```text
AzureAutomationLab
```

Create one shared VNet and subnet:

```text
Shared-vnet
└── server-subnet
```

Example address spaces:

```text
VNet:   10.10.0.0/16
Subnet: 10.10.1.0/24
```

Create an NSG such as `Shared-nsg` and associate it with `server-subnet`. Avoid exposing RDP or SSH to the entire Internet; restrict source addresses or use Azure Bastion/VPN.

## 2. Create the Automation Account

In Azure Portal:

```text
Automation Accounts -> Create
```

Create the account in a region appropriate for your organization.

## 3. Enable Managed Identity

Open the Automation Account:

```text
Identity -> System assigned -> On -> Save
```

## 4. Assign RBAC

Open the target resource group:

```text
Access control (IAM) -> Add role assignment
```

For a lab, assign:

```text
Role: Contributor
Member type: Managed identity
Member: <your Automation Account>
Scope: target resource group
```

For production, use a custom least-privilege role where possible.

## 5. Create a PowerShell 7.4 Runtime Environment

In the Automation Account:

```text
Runtime Environments -> Create
Language: PowerShell
Version: 7.4
```

The Az package is typically available as a default package.

## 6. Create the VM local-admin credential

In the Automation Account:

```text
Shared Resources -> Credentials -> Add a credential
```

Use:

```text
Name: VM-LocalAdmin
Username: a valid local Windows administrator name
Password: a strong password
```

Never store the password in GitHub or directly in the runbook.

## 7. Create the runbook

Create a PowerShell runbook such as:

```text
Create-VM
```

Paste or import `Create-VM.ps1`.

Update these fixed values in the script if necessary:

```powershell
$ResourceGroup = "AzureAutomationLab"
$VNetName = "Shared-vnet"
$SubnetName = "server-subnet"
$CredentialName = "VM-LocalAdmin"
```

If you want auto-shutdown email notification, populate `$NotificationEmail`.

## 8. Test Managed Identity

Before the full deployment, you can temporarily test:

```powershell
Disable-AzContextAutosave -Scope Process
$context = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionId $context.Subscription.Id | Out-Null
Get-AzContext
```

## 9. Deploy a VM

Use the Test pane or publish/start the runbook.

Example:

```text
VMName       = LABVM01
VMSize       = Standard_D2s_v3
Location     = eastus
Zone         = 1
ShutdownTime = 2300
```

Only `VMName` is mandatory; the rest have defaults.

## 10. Verify deployment

Confirm these resources exist:

```text
LABVM01
LABVM01-nic
LABVM01-pip
LABVM01-osdisk
shutdown-computevm-LABVM01
```

Verify the VM uses the shared VNet/subnet and that Trusted Launch, Secure Boot, vTPM, Hotpatch, boot diagnostics, and auto-shutdown are configured as expected.
