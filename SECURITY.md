# Security Policy

## Recommended practices

- Use Azure Managed Identity for Azure authentication.
- Never commit passwords, access keys, client secrets, certificates, or tokens.
- Store VM local-administrator credentials in Azure Automation Credentials or Azure Key Vault.
- Apply least-privilege RBAC in production.
- Restrict RDP/SSH access to trusted source IPs, VPN, private connectivity, or Azure Bastion.
- Review Network Security Group rules before public use.
- Enable logging and monitoring appropriate to your environment.

## Reporting a security issue

If you find a security issue in this sample, do not publish sensitive exploit details in a public issue. Use a private communication channel with the repository owner instead.
