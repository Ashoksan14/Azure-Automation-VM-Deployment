# Azure Automation VM Deployment

A reusable Azure Automation PowerShell runbook that provisions Windows Server virtual machines using a system-assigned Managed Identity and shared networking.

## Features

- Azure Automation PowerShell 7.4 runbook
- System-assigned Managed Identity authentication
- Reusable shared VNet and subnet
- Windows Server 2022 Datacenter Azure Edition Hotpatch
- Trusted Launch, Secure Boot, and vTPM
- Premium SSD OS disk
- Accelerated Networking
- Standard static public IP
- Managed boot diagnostics
- Automatic platform patching and Hotpatch
- Configurable VM name, size, region, availability zone, and shutdown time
- Duplicate-resource checks
- Partial-deployment recovery for NIC and Public IP
- Cleanup of newly created network resources when VM creation fails
- Auto-shutdown configuration

## Repository structure

```text
Azure-Automation-VM-Deployment/
├── Create-VM.ps1
├── README.md
├── LICENSE
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── docs/
│   ├── Setup-Guide.md
│   ├── Architecture.md
│   └── Troubleshooting.md
└── images/
    └── README.md
```

## Example lab naming

This repository intentionally uses generic names so it can be reused safely:

| Resource | Example |
|---|---|
| Resource group | `AzureAutomationLab` |
| VNet | `Shared-vnet` |
| Subnet | `server-subnet` |
| NSG | `Shared-nsg` |
| Automation credential | `VM-LocalAdmin` |

Change these values to match your own environment before running the script.

## Runbook parameters

| Parameter | Required | Default | Description |
|---|---:|---|---|
| `VMName` | Yes | - | VM and Windows computer name |
| `VMSize` | No | `Standard_D2s_v3` | Azure VM size |
| `Location` | No | `eastus` | Azure region; must match the VNet region |
| `Zone` | No | `1` | Availability Zone 1, 2, or 3 |
| `ShutdownTime` | No | `2300` | Daily shutdown time in HHmm format |

## Quick start

1. Create a resource group such as `AzureAutomationLab`.
2. Create `Shared-vnet` with a subnet named `server-subnet`.
3. Create `Shared-nsg` and associate it with the subnet.
4. Create an Azure Automation Account.
5. Enable its system-assigned Managed Identity.
6. Grant that identity `Contributor` on the target resource group.
7. Create a PowerShell 7.4 Runtime Environment.
8. Create an Automation credential named `VM-LocalAdmin`.
9. Create a PowerShell runbook and paste/import `Create-VM.ps1`.
10. Test with a new VM name such as `LABVM01`.

See [docs/Setup-Guide.md](docs/Setup-Guide.md) for the full walkthrough.

## Security notes

Do not hardcode passwords, subscription secrets, or tenant secrets in the script. Use Managed Identity and Azure Automation credentials or Azure Key Vault. Restrict RDP/SSH exposure to trusted source networks or use Azure Bastion/VPN.

## License

MIT. See [LICENSE](LICENSE).
