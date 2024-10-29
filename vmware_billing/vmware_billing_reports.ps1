# Prompt for vCenter credentials if not already available
$vcCredentials = Get-Credential -Message "Enter username and password"

# Get the script directory
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
# Define the path to the setup JSON file
$jsonFilePath = Join-Path -Path $scriptDirectory -ChildPath "setup.json"

# Read and parse the JSON file
if (Test-Path $jsonFilePath) {
    $setup = Get-Content -Path $jsonFilePath | ConvertFrom-Json
    # Access and display the parsed values
    $vcServers = $setup.config.vcServers
    $dataDirectoryName = $setup.config.data_directory_name
    $excelWorkbookName = $setup.config.excel_workbook_name
    $rateCpu = $setup.monthly_rates.cpu
    $rateMem = $setup.monthly_rates.mem
    $rateStorage = $setup.monthly_rates.storage
    $rateDataprotect = $setup.monthly_rates.dataprotect 
    $rateManaged = $setup.monthly_rates.managed
    $rateMssql = $setup.monthly_rates.mssql
    $rateMysql = $setup.monthly_rates.mysql
    $rateOracle = $setup.monthly_rates.oracle
}
else {
    Write-Host "JSON file not found at $jsonFilePath"
    exit
}

# Define file paths relative to the script directory
$excelPath = Join-Path -Path $scriptDirectory -ChildPath $excelWorkbookName
$dataPath = Join-Path -Path $scriptDirectory -ChildPath $dataDirectoryName
if (-not (Test-Path -Path $dataPath)) {
    New-Item -Path $dataPath -ItemType Directory -Force | Out-Null
}

# Initialize arrays for VM data and billing data
$vmData = @()
$vmBillingData = @()

# Start a new Excel application
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Add()

# Function to calculate and format totals
function CalculateTotals($group, $multiplier, $label) {
    [PSCustomObject]@{
        vmCostOracle = $label
        vmCostTotal  = ($group | Measure-Object -Property vmCostTotal -Sum).Sum * $multiplier
        vmCostAdj    = ($group | Measure-Object -Property vmCostAdj -Sum).Sum * $multiplier
    }
}

function ConvertToExcel {
    param (
        [string]$csvfile,
        [object]$workbook,
        [string]$customer
    )

    # Read the CSV data into a variable
    $csvData = Get-Content -Path $csvfile

    # Track the current Excel row
    $rowIndex = 1

    # Create a new worksheet in the specified workbook, with the same name as the customer
    $worksheet = $workbook.Sheets.Add()
    $worksheet.Name = $customer

    # Iterate through each line in the CSV data
    foreach ($line in $csvData) {
        if ($line -eq "") {
            # Keep the blank line in the output
            $rowIndex++
            continue
        }
        
        # Split the line into cells by comma
        $cells = $line -split ","

        # Iterate over cells to add data to each column
        for ($colIndex = 0; $colIndex -lt $cells.Length; $colIndex++) {
            $worksheet.Cells.Item($rowIndex, $colIndex + 1).Value2 = $cells[$colIndex].Trim('"')
        }

        # Bold and light gray background for headers in the first and fourth rows
        if ($rowIndex -eq 1 -or $rowIndex -eq 4) {
            for ($col = 1; $col -le $cells.Length; $col++) {
                $cell = $worksheet.Cells.Item($rowIndex, $col)
                $cell.Font.Bold = $true
                $cell.Interior.Color = [System.Drawing.Color]::FromArgb(217, 217, 217).ToArgb()
            }
        }

        # Check for "Monthly Cost" and "Annual Cost" rows and format
        if ($cells[11] -eq "Monthly Cost" -or $cells[11] -eq "Annual Cost") {
            $totalCostLabelCell = $worksheet.Cells.Item($rowIndex, 12)
            $totalCostCell = $worksheet.Cells.Item($rowIndex, 13) 
            foreach ($formatCell in $totalCostLabelCell , $totalCostCell) {
                $formatCell.Font.Bold = $true
                $formatCell.Interior.Color = [System.Drawing.Color]::FromArgb(255, 255, 0).ToArgb() # Yellow background
                $border = $formatCell.Borders
                $border.LineStyle = 1  # xlContinuous
                $border.Weight = 2     # xlThick
                $border.Color = [System.Drawing.Color]::FromArgb(0, 0, 0).ToArgb()  # Black color
            }
            $totalCostCell.NumberFormat = "$#,##0.00"  # Currency format for USD
        }
        $rowIndex++        
    }
    # Center-align all cells in the used range
    $usedRange = $worksheet.UsedRange
    $usedRange.HorizontalAlignment = -4108  # -4108 is the Excel constant for center alignment    
    # Adjust column widths for better readability
    $worksheet.Columns.AutoFit()
}

# Connect to vCenter and retrieve VMs tagged as "Billable"
foreach ($vcServer in $vcServers) {
    try {
        Connect-VIServer -Server $vcServer -Credential $vcCredentials -ErrorAction Stop
        $vms = Get-VM -Tag "Billable" -ErrorAction Stop
        $vmData += $vms
    }
    catch {
        Write-Host "Failed to connect to $vcServer or retrieve VMs. Check server connectivity and credentials."
        continue
    }
}

# Process each VM to generate billing data
foreach ($vm in $vmData) {
    try {
        # Retrieve custom attributes and create billing object
        $vmObject = [PSCustomObject]@{
            vmGuestName        = $vm.Name
            vmContactDept      = ((Get-Annotation -Entity $vm -CustomAttribute "Billing-Department").Value -split ' ' | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower() }) -join ''
            vmContactDeptOwner = (Get-Annotation -Entity $vm -CustomAttribute "Billing-DepartmentOwner").Value
            vmContactSbo       = (Get-Annotation -Entity $vm -CustomAttribute "Billing-SBO").Value
            vmContactTech      = (Get-Annotation -Entity $vm -CustomAttribute "Billing-TechContact").Value
            vmStatCpu          = $vm.NumCpu
            vmStatMem          = $vm.MemoryGB
            vmStatStorage      = ($vm | Get-HardDisk | Measure-Object -Property CapacityGB -Sum).Sum
            vmPropManaged      = if ((Get-Annotation -Entity $vm -CustomAttribute "Billing-Managed").Value -eq "true") { 1 } else { 0 }
            vmDbMssql          = if ((Get-Annotation -Entity $vm -CustomAttribute "Billing-MSSQL").Value -eq "true") { 1 } else { 0 }
            vmDbMysql          = if ((Get-Annotation -Entity $vm -CustomAttribute "Billing-MySQL").Value -eq "true") { 1 } else { 0 }
            vmDbOracle         = if ((Get-Annotation -Entity $vm -CustomAttribute "Billing-Oracle").Value -eq "true") { 1 } else { 0 }
            # Initialize costs
            vmCostCpu          = 0
            vmCostMem          = 0
            vmCostStorage      = 0
            vmCostDataprotect  = 0
            vmCostManaged      = 0
            vmCostMssql        = 0
            vmCostMysql        = 0
            vmCostOracle       = 0
            vmCostTotal        = 0
            vmCostAdj          = 0  # Placeholder for potential adjustments
        }
        # Calculate costs
        $vmObject.vmCostCpu = $vmObject.vmStatCpu * $rateCpu
        $vmObject.vmCostMem = $vmObject.vmStatMem * $rateMem
        $vmObject.vmCostStorage = $vmObject.vmStatStorage * $rateStorage
        $vmObject.vmCostDataprotect = $vmObject.vmStatStorage * $rateDataprotect
        $vmObject.vmCostManaged = $vmObject.vmPropManaged * $rateManaged
        $vmObject.vmCostMssql = $vmObject.vmDbMssql * $rateMssql
        $vmObject.vmCostMysql = $vmObject.vmDbMysql * $rateMysql
        $vmObject.vmCostOracle = $vmObject.vmDbOracle * $rateOracle
        $vmObject.vmCostTotal = $vmObject.vmCostCpu + $vmObject.vmCostMem + $vmObject.vmCostStorage + $vmObject.vmCostDataprotect + $vmObject.vmCostManaged + $vmObject.vmCostMssql + $vmObject.vmCostMysql + $vmObject.vmCostOracle
        $vmBillingData += $vmObject
    }
    catch {
        Write-Warning "Failed to process VM: $($vm.Name). Skipping VM."
        continue
    }
}

# Group billing data by customer and export to CSV with monthly/yearly summaries
$groupedData = $vmBillingData | Group-Object -Property vmContactDept
foreach ($group in $groupedData) {
    $customer = $group.Name
    $fileName = "$customer.csv"
    $csvPath = Join-Path -Path $dataPath -ChildPath $fileName
    try {
        # Create the CSV with headers and contact info first
        $contactInfo = [PSCustomObject]@{
            Customer    = $group.Group[0].vmContactDept
            Owner       = $group.Group[0].vmContactDeptOwner
            SBO         = $group.Group[0].vmContactSbo
            TechContact = $group.Group[0].vmContactTech
        }
        $contactInfo | Export-Csv -Path $csvPath -NoTypeInformation -Force

        # Add a blank line
        Add-Content -Path $csvPath -Value ""

        # Define header for VM stats and costs
        $vmStatsHeader = "VM,#CPU,Memory(GB),Storage(GB),CpuCost,MemoryCost,StorageCost,BackupCost,ManagedServicesCost,MSsqlCost,MysqlCost,OracleCost,TotalCost,AdjustedCost"
        Add-Content -Path $csvPath -Value $vmStatsHeader  

        # Write VM data to the CSV
        $group.Group | ForEach-Object {
            $line = "$($_.vmGuestName),$($_.vmStatCpu),$($_.vmStatMem),$($_.vmStatStorage),$($_.vmCostCpu),$($_.vmCostMem),$($_.vmCostStorage),$($_.vmCostDataprotect),$($_.vmCostManaged),$($_.vmCostMssql),$($_.vmCostMysql),$($_.vmCostOracle),$($_.vmCostTotal),$($_.vmCostAdj)"
            Add-Content -Path $csvPath -Value $line
        }             

        # Generate and export monthly and yearly totals
        $monthlyTotals = CalculateTotals -group $group.Group -multiplier 1 -label "Monthly Cost"
        $annualTotals = CalculateTotals -group $group.Group -multiplier 12 -label "Annual Cost"
        foreach ($total in $monthlyTotals, $annualTotals) {
            $line = ",,,,,,,,,,,$($total.vmCostOracle),$($total.vmCostTotal),$($total.vmCostAdj)"
            Add-Content -Path $csvPath -Value $line
        }
    }
    catch {
        Write-Host "Failed to export billing data for '$customer' : "
        Write-Host $_.Exception.Message
    }
    # Add CSV data to a worksheet in the Excel workbook
    try {
        ConvertToExcel -csvfile $csvPath -workbook $workbook -customer $customer
        Write-Host "Successfully converted '$csvPath' to Excel for customer '$customer'."
    }
    catch {
        # Catch block to handle errors
        Write-Host "An error occurred while converting the CSV file '$csvPath' to Excel: "
        Write-Host $_.Exception.Message
    }    
}

# Save the workbook and close Excel
$workbook.SaveAs($excelPath)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

# Disconnect from vCenter
foreach ($vcServer in $vcServers) {
    Disconnect-VIServer -Server $vcServer -Confirm:$false
}