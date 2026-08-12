# Architecture

## Logical design

```text
                         Azure Automation Account
                                  |
                         PowerShell 7.4 Runbook
                                  |
                     System-assigned Managed Identity
                                  |
                   Azure Resource Manager / Az PowerShell
                                  |
             +--------------------+--------------------+
             |                                         |
      Shared infrastructure                      Per-VM resources
             |                                         |
      Shared-vnet                              <VMName>
      server-subnet                            <VMName>-nic
      Shared-nsg                               <VMName>-pip
                                               <VMName>-osdisk
                                  |
                         Windows Server 2022
                         Trusted Launch
                         Secure Boot + vTPM
                         Hotpatch
                         Premium SSD
                         Auto-shutdown
```

## Design choices

The VNet, subnet, and NSG are shared instead of being recreated for every VM. Each VM gets unique compute, NIC, public IP, and OS disk names derived from the `VMName` parameter.

The runbook authenticates through Managed Identity, so no Azure user password, service-principal secret, or certificate needs to be embedded in code.

The local Windows administrator credential is stored as an Azure Automation credential and retrieved at runtime.

## Idempotency and recovery

The runbook stops if the VM or OS disk already exists. A Public IP or unattached NIC left by a partial deployment can be reused. If the VM create operation fails after the runbook created a NIC or Public IP, those newly created networking resources are removed.
