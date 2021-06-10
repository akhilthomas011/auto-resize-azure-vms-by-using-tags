<#PSScriptInfo

.VERSION 2.00

.AUTHOR Akhil Thomas

.COPYRIGHT
 
.TAGS VirtualMachine AutomationAccount Runbook Tag Azure VMSize

.LICENSEURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>


#Requires -Module Az.Accounts
#Requires -Module Az.Resources
#Requires -Module Az.Compute



<#
    .SYNOPSIS
        This Azure Automation runbook automates Virtual Machine Resizing in an Azure subscription using Tags(AZ Module). 

    .DESCRIPTION
        This script resizes your Azure VMs using the tags specified on the VMs. The script has 3 parameters - RGEXCEPTIONS,VMEXCEPTIONS,SCALEUP.
        To make this automation script work, we have to specify 2 tags on each desired VM - 'ScaleUpSize' and 'ScaleDownSize'.
        Specify the VM scale up VM size in the ScaleupSize tag. In the ScaledownSize tag, specify the VM scale down size. Please note that both scale up and scale down
        occurs only if both tags are set correctly on desired VMs. If you want to include a VM in auto scaling later, just add the two tags and they will be added automatically for the schedule.
        
        Example: https://github.com/azureautomation/auto-resize-azure-vms-by-using-tags/raw/master/images/tags.png

        The script works best with Runbook Scheduler with 2 schedules - For Scale Up and Scale Down.In Scale Up schedule, set the 'SCALEUP' parameter to $True and in 
        Scale Down schedule, set the 'SCALEUP' parameter to $False.
        
        Also, script assumes that you have created 'Azure Run as Account' and has the default Azure Connection asset 'AzureRunAsConnection'.
        This scipt uses AZ module.
         

    .PARAMETER RGEXCEPTIONS

        In 'RGEXCEPTIONS', you can specify the Resource Groups which you need to exclude from scaling. The RGs specified here will not be considered for scaling even if the VMs
        in that RG has scaling tags.

        By default, the value will be null. If you are excluding multiple Resource Groups, enter the names comma separated.

        Example: https://i1.gallery.technet.s-msft.com/rescale-azure-vms-by-using-c6a6a5ae/image/file/206742/1/parameters.png
    
    .PARAMETER VMEXCEPTIONS

        In 'VMEXCEPTIONS', you can specify the Virtual Machines which you need to exclude from scaling. The VMs specified here will not be considered for scaling even if the VMs
        have the scaling tags.

        By default, the value will be null. If you are excluding multiple Virtual Machines, enter the names comma separated.

        Example: https://github.com/azureautomation/auto-resize-azure-vms-by-using-tags/raw/master/images/parameters.png

    
    .PARAMETER SCALEUP
        The third parameter 'SCALEUP' acts as a switch. If it is called, all the VMs in the subscription which have scaling tags set and not in
        RGEXCEPTIONS/VMEXCEPTIONS will be scaled up. Else, they will be scaled down. Default action is scale down.

#>


param( 
    [parameter(Mandatory=$false)] 
    [String] $RGexceptions, 
    [parameter(Mandatory=$false)] 
    [String] $VMexceptions, 
    [parameter(Mandatory=$false)] 
    [bool]$scaleUp 
) 
Function Get-Timestamp{
$(Get-Date -Format “MM/dd/yyyy HH:mm K”) + " -"
}

$connectionName = "AzureRunAsConnection" 
try 
{ 
    # Get the connection "AzureRunAsConnection " 
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName          
 
    Write-Output "$(Get-Timestamp) Logging in to Azure..." 
    Connect-AzAccount -ServicePrincipal -Tenant $($servicePrincipalConnection.TenantId) -ApplicationId $($servicePrincipalConnection.ApplicationId) -CertificateThumbprint $($servicePrincipalConnection.CertificateThumbprint)  | Out-Null
} 
catch { 
    if (!$servicePrincipalConnection) 
    { 
        $ErrorMessage = "$(Get-Timestamp) Connection $connectionName not found." 
        throw $ErrorMessage 
    } else{ 
        Write-Error -Message $_.Exception 
        throw $_.Exception 
    } 
} 
 

# Function for autoscaling
Function Start-VMAutoScaling ([String]$RGexceptions,[String]$VMexceptions,[bool]$scaleUp){ 
    #TypeCast arrays
    [array]$RGexceptions = $RGexceptions.Split(',') 
    [array]$VMexceptions = $VMexceptions.Split(',') 
 
    #Switch Scaling Tag
    if($scaleUp){ 
        $scaleTagSwitch= 'ScaleUpSize'
        Write-Output "`n`nOBJECTIVE: SCALE UP`n" 
    } 
    else{ 
        $scaleTagSwitch= 'ScaleDownSize' 
        Write-Output "`n`nOBJECTIVE: SCALE DOWN`n" 
    } 

    #Iterate through Resource Groups
    $RGs = Get-AzResourceGroup 
    foreach($RG in $RGs){ 
        $RGName = $RG.ResourceGroupName
        Write-Output "`n`n$(Get-Timestamp) RESOURCE GROUP: $RGName" 
        if($RGName -notin $RGexceptions){ 
            $VMs = Get-AzVM -ResourceGroupName $RGName
            if($VMs.Count -eq 0){
                Write-Output "  Status: No VMs in the Resource Group"
                Continue
            }
            #Iterate through Virtual Machines
            foreach ($VM in $VMs){ 
                $VMName = $VM.Name
                Write-Output "`n   VIRTUAL MACHINE: $VMName"
                if($VMName -notin $VMexceptions){ 
                    $VMDetail = Get-AzVM -ResourceGroupName $RGName -Name $VMName 
                    $ScaleSize = $VMDetail.Tags[$scaleTagSwitch] 
                    $VMSize = $VMDetail.HardwareProfile.VmSize 
                    if(($ScaleSize) -and ($VMSize -ne $ScaleSize)){ 
                        Write-Output "     Action: Resize"  
                        Write-Output "     Current VM Size: $VMSize   $scaleTagSwitch : $ScaleSize"  
                        $VMStatus = Get-AzVM -ResourceGroupName $RGName -Name $VMName -Status 
                        if($VMStatus.Statuses[1].DisplayStatus -eq "VM running"){ 
                            Write-Output "     Status: Stopping VM"  
                            Stop-AzVM -ResourceGroupName $RGName -Name $VMName -Force | Out-Null 
                        }
                        $VM.HardwareProfile.VmSize = $ScaleSize 
                        Update-AzVM -VM $VM -ResourceGroupName $RGName | Out-Null
                        if($VMStatus.Statuses[1].DisplayStatus -eq "VM running"){
                            Start-AzVM -ResourceGroupName $RGName -Name $VMName | Out-Null 
                            Write-Output "     Status: Starting VM"  
                        } 
                        Write-Output "     Status: VM Resized to $ScaleSize"
                    } 
                    elseif(!$ScaleSize) { 
                        Write-Output "     Action: Nil"  
                        Write-Output "     Reason: No Tag '$scaleTagSwitch' found"
                    } 
                    else{ 
                        Write-Output "     Action: Nil"  
                        Write-Output "     Reason: Current VM size matches $scaleTagSwitch"
                    }            
                }#VM Exception Ends 
                else{ 
                    Write-Output "     Action: Nil"  
                    Write-Output "     Reason: VM is in Exception List"
                } 
            } 
        } 
        else{ 
            Write-Output "     Action: Nil"  
            Write-Output "     Reason: Resource Group is in Exception List"
        }#RG Exception Ends 
    } 
}
 
# Call Resizing function
Start-VMAutoScaling $RGexceptions $VMexceptions $scaleUp
Write-Output "`n`n`n`n Execution completed"