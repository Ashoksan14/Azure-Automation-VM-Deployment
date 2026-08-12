<#!
.SYNOPSIS
Creates a Windows Server VM from an Azure Automation PowerShell runbook.

.DESCRIPTION
Uses the Automation Account system-assigned Managed Identity, a shared VNet/subnet,
and an Azure Automation credential to provision a Windows Server 2022 Azure Edition
Hotpatch VM with Trusted Launch, Secure Boot, vTPM, Premium SSD, accelerated networking,
managed boot diagnostics, and auto-shutdown.

.NOTES
Before use:
1. Enable the Automation Account system-assigned Managed Identity.
2. Grant it Contributor on the target resource group.
3. Create an Automation credential named VM-LocalAdmin.
4. Create the shared VNet/subnet and associate an NSG with the subnet.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [string]$VMSize = "Standard_D2s_v3",

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [ValidateSet("1", "2", "3")]
    [string]$Zone = "1",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^([01][0-9]|2[0-3])[0-5][0-9]$')]
    [string]$ShutdownTime = "2300"
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Environment settings - update these values for your Azure environment.
# -----------------------------------------------------------------------------
$ResourceGroup = "AzureAutomationLab"
$VNetName = "Shared-vnet"
$SubnetName = "server-subnet"
$CredentialName = "VM-LocalAdmin"
$ShutdownTimeZone = "India Standard Time"
$NotificationEmail = ""

# Resource names derived from the VM name.
$NICName = "$VMName-nic"
$PublicIPName = "$VMName-pip"
$OSDiskName = "$VMName-osdisk"

$CreatedNICByRunbook = $false
$CreatedPIPByRunbook = $false

if ($VMName.Length -gt 15) {
    throw "VMName must be 15 characters or less because it is also used as the Windows computer name."
}

Write-Output ""
Write-Output "=============================================="
Write-Output " AZURE VM AUTOMATION"
Write-Output "=============================================="
Write-Output "VM Name       : $VMName"
Write-Output "VM Size       : $VMSize"
Write-Output "Location      : $Location"
Write-Output "Zone          : $Zone"
Write-Output "Resource Group: $ResourceGroup"
Write-Output "VNet          : $VNetName"
Write-Output "Subnet        : $SubnetName"
Write-Output "Shutdown Time : $ShutdownTime"
Write-Output "=============================================="

# Connect using the Automation Account Managed Identity.
Disable-AzContextAutosave -Scope Process
$Context = (Connect-AzAccount -Identity).Context
$Context = Set-AzContext -SubscriptionId $Context.Subscription.Id -DefaultProfile $Context
Write-Output "Connected to Azure successfully."

# Validate resource group.
$RG = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (-not $RG) {
    throw "Resource Group '$ResourceGroup' does not exist."
}

# Prevent duplicate VM creation.
$ExistingVM = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName -ErrorAction SilentlyContinue
if ($ExistingVM) {
    throw "VM '$VMName' already exists. Please choose another VM name."
}

# Detect a leftover OS disk from a failed/old deployment.
$ExistingDisk = Get-AzDisk -ResourceGroupName $ResourceGroup -DiskName $OSDiskName -ErrorAction SilentlyContinue
if ($ExistingDisk) {
    throw "OS disk '$OSDiskName' already exists. Review or remove it before rerunning this deployment."
}

# Retrieve the VM local-admin credential stored in Azure Automation.
$Credential = Get-AutomationPSCredential -Name $CredentialName
if (-not $Credential) {
    throw "Automation Credential '$CredentialName' was not found."
}

# Retrieve shared VNet and validate its location.
$VNet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetName -ErrorAction SilentlyContinue
if (-not $VNet) {
    throw "VNet '$VNetName' does not exist."
}

if ($VNet.Location -ne $Location) {
    throw "Location mismatch. Requested VM location '$Location' does not match VNet location '$($VNet.Location)'."
}

$Subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet -Name $SubnetName -ErrorAction SilentlyContinue
if (-not $Subnet) {
    throw "Subnet '$SubnetName' does not exist in VNet '$VNetName'."
}

# Reuse an existing PIP after a partial run, otherwise create it.
$PublicIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIPName -ErrorAction SilentlyContinue
if ($PublicIP) {
    Write-Output "Public IP already exists. Reusing: $PublicIPName"
}
else {
    Write-Output "Creating Public IP: $PublicIPName"
    $PublicIP = New-AzPublicIpAddress `
        -Name $PublicIPName `
        -ResourceGroupName $ResourceGroup `
        -Location $Location `
        -Sku Standard `
        -AllocationMethod Static `
        -IpAddressVersion IPv4 `
        -Zone 1,2,3 `
        -Force
    $CreatedPIPByRunbook = $true
}

# Reuse a free NIC after a partial run, otherwise create it.
$NIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NICName -ErrorAction SilentlyContinue
if ($NIC) {
    if ($NIC.VirtualMachine -and $NIC.VirtualMachine.Id) {
        throw "NIC '$NICName' is already attached to another VM."
    }
    Write-Output "NIC already exists and is free. Reusing: $NICName"
}
else {
    Write-Output "Creating NIC: $NICName"
    $NIC = New-AzNetworkInterface `
        -Name $NICName `
        -ResourceGroupName $ResourceGroup `
        -Location $Location `
        -SubnetId $Subnet.Id `
        -PublicIpAddressId $PublicIP.Id `
        -EnableAcceleratedNetworking
    $CreatedNICByRunbook = $true
}

# VM security and hardware profile.
$VMConfig = New-AzVMConfig `
    -VMName $VMName `
    -VMSize $VMSize `
    -SecurityType TrustedLaunch `
    -EnableSecureBoot $true `
    -EnableVtpm $true

# Windows guest settings and Hotpatch.
$VMConfig = Set-AzVMOperatingSystem `
    -VM $VMConfig `
    -Windows `
    -ComputerName $VMName `
    -Credential $Credential `
    -ProvisionVMAgent `
    -EnableAutoUpdate `
    -PatchMode "AutomaticByPlatform" `
    -AssessmentMode "ImageDefault" `
    -EnableHotpatching

# Windows Server 2022 Datacenter Azure Edition Hotpatch image.
$VMConfig = Set-AzVMSourceImage `
    -VM $VMConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2022-datacenter-azure-edition-hotpatch" `
    -Version "latest"

# Premium SSD OS disk, deleted with VM.
$VMConfig = Set-AzVMOSDisk `
    -VM $VMConfig `
    -Name $OSDiskName `
    -CreateOption FromImage `
    -StorageAccountType "Premium_LRS" `
    -DeleteOption Delete

# Attach NIC and delete it with the VM.
$VMConfig = Add-AzVMNetworkInterface `
    -VM $VMConfig `
    -Id $NIC.Id `
    -Primary `
    -DeleteOption Delete

# Managed boot diagnostics; no custom storage account is required.
$VMConfig = Set-AzVMBootDiagnostic -VM $VMConfig -Enable
$VMConfig.LicenseType = "Windows_Server"

try {
    Write-Output "Creating VM '$VMName'..."
    $null = New-AzVM `
        -ResourceGroupName $ResourceGroup `
        -Location $Location `
        -VM $VMConfig `
        -Zone $Zone
    Write-Output "VM created successfully."
}
catch {
    Write-Error "VM creation failed: $($_.Exception.Message)"

    if ($CreatedNICByRunbook) {
        Remove-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NICName -Force -ErrorAction SilentlyContinue
    }
    if ($CreatedPIPByRunbook) {
        Remove-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIPName -Force -ErrorAction SilentlyContinue
    }
    throw
}

# Configure auto-shutdown.
$VM = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName

if ([string]::IsNullOrWhiteSpace($NotificationEmail)) {
    $NotificationSettings = @{ status = "Disabled" }
}
else {
    $NotificationSettings = @{
        status             = "Enabled"
        timeInMinutes      = 30
        notificationLocale = "en"
        emailRecipient     = $NotificationEmail
    }
}

$ShutdownProperties = @{
    status = "Enabled"
    taskType = "ComputeVmShutdownTask"
    dailyRecurrence = @{ time = $ShutdownTime }
    timeZoneId = $ShutdownTimeZone
    targetResourceId = $VM.Id
    notificationSettings = $NotificationSettings
}

$ShutdownScheduleName = "shutdown-computevm-$VMName"
$null = New-AzResource `
    -ResourceGroupName $ResourceGroup `
    -ResourceType "Microsoft.DevTestLab/schedules" `
    -Name $ShutdownScheduleName `
    -Location $Location `
    -ApiVersion "2018-09-15" `
    -Properties $ShutdownProperties `
    -Force

# Final deployment summary.
$CreatedNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NICName
$CreatedIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIPName
$PrivateIP = $CreatedNIC.IpConfigurations[0].PrivateIpAddress

Write-Output ""
Write-Output "=================================================="
Write-Output " VM CREATION COMPLETED SUCCESSFULLY"
Write-Output "=================================================="
Write-Output "VM Name        : $VMName"
Write-Output "Resource Group : $ResourceGroup"
Write-Output "Location       : $Location"
Write-Output "Availability   : Zone $Zone"
Write-Output "VM Size        : $VMSize"
Write-Output "Image          : Windows Server 2022 Azure Edition Hotpatch"
Write-Output "Trusted Launch : Enabled"
Write-Output "Secure Boot    : Enabled"
Write-Output "vTPM           : Enabled"
Write-Output "OS Disk        : $OSDiskName (Premium_LRS)"
Write-Output "VNet           : $VNetName"
Write-Output "Subnet         : $SubnetName"
Write-Output "NIC            : $NICName"
Write-Output "Private IP     : $PrivateIP"
Write-Output "Public IP      : $($CreatedIP.IpAddress)"
Write-Output "Shutdown Time  : $ShutdownTime ($ShutdownTimeZone)"
Write-Output "=================================================="
