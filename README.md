Auto Resize Azure VMs by using Tags
===================================

            

This script resizes your Azure VMs using the tags specified on the VMs. The script has 3 parameters - RGEXCEPTIONS,VMEXCEPTIONS,SCALEUP. To make this automation script work, we have to specify 2 tags on each desired VM - 'ScaleUpSize' and 'ScaleDownSize'.
 Specify the Scale Up VM size in the ScaleupSize tag. In the ScaledownSize tag, specify the VM Scale Down size. Please note that both scale up and scale down occurs only if both tags are set correctly on desired VMs. If you want to include a VM in auto scaling later, just add the two tags and they will be added automatically for the schedule.


 


![Image](https://github.com/azureautomation/auto-resize-azure-vms-by-using-tags/raw/master/images/tags.png)


 


**Parameters**


**RGEXCEPTIONS**


In 'RGEXCEPTIONS', you can specify the Resource Groups which you need to exclude from scaling. The RGs specified here will not be considered for scaling even if the VMs in that RG has scaling tags.

By default, the value will be null. If you are excluding multiple Resource Groups, enter the names comma separated.


 


**VMEXCEPTIONS**


In 'VMEXCEPTIONS', you can specify the Virtual Machines which you need to exclude from scaling. The VMs specified here will not be considered for scaling even if the VMs have the scaling tags.

By default, the value will be null. If you are excluding multiple Virtual Machines, enter the names comma separated.


**SCALEUP**


The third parameter 'SCALEUP' acts as a switch. If it is set to 'True', all the VMs in the subscription which have scaling tags set and not in RGEXCEPTIONS/VMEXCEPTIONS will be scaled up. Else if it is set to 'False', they will be scaled down.



Defaut value is 'False'.


 


![Image](https://github.com/azureautomation/auto-resize-azure-vms-by-using-tags/raw/master/images/parameters.png)


 


**NOTE**: The script works best with Runbook Scheduler with 2 schedules - For Scale Up and Scale Down. In Scale Up schedule, set the 'SCALEUP' parameter to $True and in Scale Down schedule, set the 'SCALEUP' parameter to $False.
        
Also, script assumes that you have created 'Azure Run as Account' and has the default Azure Connection asset 'AzureRunAsConnection'. It also assumes that the required Az Modules specified below are added to Modules Gallery. 

```powershell
Requires -Module Az.Accounts  
Requires -Module Az.Resources  
Requires -Module Az.Compute  
```


Please send your valuable feedbacks to akhilthomas011@gmail.com
