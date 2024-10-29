# VMware Billing Automation Script

## Overview
This PowerShell script automates the billing process for VMware virtual machines by collecting resource usage data, calculating costs based on predefined rates, and generating detailed billing reports in both CSV and Excel formats.

## Features
- Automated VM resource usage collection
- Custom billing rate application
- Multi-vCenter server support
- Automated Excel report generation
- Customer-based billing segregation

## Prerequisites
- PowerShell 5.1 or higher
- VMware PowerCLI
- Microsoft Excel
- vCenter Server access credentials
- Required VM custom attributes:
  - Billing-Department
  - Billing-DepartmentOwner
  - Billing-SBO
  - Billing-TechContact
  - Billing-Managed
  - Billing-MSSQL
  - Billing-MySQL
  - Billing-Oracle

## Configuration
### setup.json
The script uses a configuration file (`setup.json`) that contains:
- vCenter server addresses
- Data directory settings
- Excel workbook configuration
- Billing rates for:
  - CPU
  - Memory
  - Storage
  - Data protection
  - Managed services
  - Database services (MSSQL, MySQL, Oracle)

Example configuration:
```json
{
  "config": {
    "vcServers": ["vcenter1.domain.com", "vcenter2.domain.com"],
    "data_directory_name": "data",
    "excel_workbook_name": "billing_report.xlsx"
  },
  "monthly_rates": {
    "cpu": 8.17,
    "mem": 1.25,
    "storage": 0.15,
    "dataprotect": 0.05,
    "managed": 100.00,
    "mssql": 150.00,
    "mysql": 100.00,
    "oracle": 200.00
  }
}