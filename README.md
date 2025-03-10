# Example of a Windows VM on Azure with dbt-fabric and dbt-core

### Requires:
1. An Azure subscription
2. RBAC to create resources
3. Az PowerShell

### Usage:
Deploy by running: `./deploy.ps1` and expect to be prompted to provide desired vm password.

### What to expect:
1. Once finished you will have a virtual machine running Windows with dbt installed accessible by bastion with a local account.