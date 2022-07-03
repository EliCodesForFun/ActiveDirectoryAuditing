#This script will read the user input in as $samaccountname, then use either a specified directory or a typed directory, and export a spreadsheet with the current date added.

#TODO Ideas 1/3/22:
#0 VERY COOL IDEA - do a search for first name and last name by parsing the string and doing an AND search. ex. match "Jo Smit" with "Joseph Smith"
# -- Get-ADUser -Server $server -Filter{Name -like "*Smit*John*"} ## will return John Smith as the result. However be careful with last name searches that return multiple results... 
#Fuzzy Name Search Logic:
        #Requirement: FirstName LastName format. Use shortened names to match Jac to Jacob or Jack, but not but not vice versa.
        #if name is John Smith - parse string into 2 strings in an array(list?) using space as the delimiter.
        #build the $nameSearch = "*"+array[1]+"*"+array[2]+"*"


#1.Add in a condition for the multi-server search so that it prints "not found on either server" after attempting a search on both servers.
#2. Handle duplicates
#3. Idea - regex fix "FirstName LastName" --> "LastName, FirstName"
#4. Cleaner output for missing names at the end.
#5. Trim "" when checking path to improve copy-pasting paths from Windows.

Import-Module ActiveDirectory



#This method adds the CN Information - used with individual users.
Function Get-FilteredMemberOf{
    Param($server, $name, $dir_final)
    
    $nameReturned = Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties samaccountname | select samaccountname
        if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
        {
            Write-Host "found user " $nameReturned " and adding formatted MemberOf list."
        }
        
    [string]$groupsReturned = Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties memberOf| select -ExpandProperty memberOf
    $ArrayOfString = $groupsReturned -split ","
    $ArraySorted = ($ArrayOfString | sort)
    
    [System.Collections.ArrayList]$finalArrayList = "", "CN Only MemberOf List" #gives a heading for index[0] in ArrayList

    
    #Will add the values that contain "CN" to our finalArrayList    
    Foreach ($i in $ArraySorted)
    {
        if($i.Contains("CN"))
        {
            $finalArrayList.Add($i) | out-null #this keeps the ArrayList.Add from echoing to PowerShell each line.                    
        }    
    }
     #Writes finalArrayList to file
     $finalArrayList | Out-File -FilePath $dir_final -Append
}

Function Get-UserInfoMultiServer{
    Param ($server, $name, $filter_on, $dir_final)
    if($server -eq "multi")
    {
        UserInfoIndividualV2 "server1.com" $name $filter_on $dir_final
        UserInfoIndividualV2 "server2.loc" $name $filter_on $dir_final
    }
    else
    {
        Write-Host "Get-UserInfoMultiServer function was called incorrectly"
    }

}

Function Get-UserInfoIndividualV2{
#This function has the CN filtering down removed from the V1, as this will be utilized within the BatchV2 version.
#This Function will be able to search for any user given a server (domain), name, filter (such as "samaccountname", "Name", "UserPrincipalName"), and a directory name.
#This provides error checking in case we don't find the user, or have a server issue.
    Param ($server, $name, $filter_on, $dir_final)
    #Write-Host "params are" $server, $name, $filter_on, $dir_final
    
    #This will do a multi-check for samaccountname, DisplayName, UserPrincipalName
    if($filter_on -eq "multi")
    {
        #looks up by Name AND samaccountname
        Get-ADUser -Server $server -Filter {Name -eq $name} -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
        Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 

        #the 3 checks required for looking up the Logon name by domain (UserPrincipalName)
        Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server1.com'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name="MemberOf";expression={$_.memberof -join ";"}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
        Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server2.com'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name="MemberOf";expression={$_.memberof -join ";"}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
        Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server2.com'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name="MemberOf";expression={$_.memberof -join ";"}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
    }        

    else
    {
        #checks if user was found using the selected filter.
        $nameReturned = Get-ADUser -Server $server -Filter {$filter_on -eq $name} -Properties samaccountname | select samaccountname
        if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
        {
            #This part pipes the information to csv
            Get-ADUser -Server $server -Filter {$filter_on -eq $name} -Properties samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,memberOf |select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append
        
            #Gets the displayName found
            $displayNameReturned = Get-ADUser -Server $server -Filter {$filter_on -eq $name} -Properties displayname | select -ExpandProperty displayname
            
            #Output when successful
            $str_output = "`nUser " + $name + " named [" + $displayNameReturned + "] successfully found on " + $server + " and exported to " + $dir_final + "`n"
            Write-Host $str_output
        }
        else 
        {
            #Output when unsuccessful
            $str_output = "`nUser " + $name + " not found on " + $server + "! Please try again." + "`n"
            Write-Host $str_output
        }
    }
}



Function Get-UserInfoBatchV2{
    #This will batch search using the server name, directory, filter, search type, and name list path.
    Param ($server, $name_list_path, $search_type, $dir_final)
    $UserNamesList = get-content -path $name_list_path    #uses the inputted path to grab names line by line.
    $successfulLines = 0
    

    if($server -eq "multi")
    {

        ###Might need to be changed, but currently this function will just do a Multi-server search for Multiple filters (name, samaccountname, userprincipalname).
        ###This is because I need to add an extra parameter to this funciton and rewrite/reclean the logic in the Main function.
        foreach ($name in $UserNamesList)
        {       
            Get-UserInfoMultiServer "multi" $name "multi" $dir_final
            #Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -Append -NoTypeInformation -Encoding UTF8     
        }
    }
    else{
        #This loop uses the Username syntax by samaccountname<<<
        if($search_type -eq 1)
        {
            foreach ($name in $UserNamesList)
            {       
                Get-UserInfoIndividualV2 $server $name "samaccountname" $dir_final
                #Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -Append -NoTypeInformation -Encoding UTF8     
            }
        }

        #this loop uses the syntax of "Last Name, First Name" as appearing in Active Directory. ex. "Smith, John"
        elseif($search_type -eq 2)
        {            
            foreach ($name in $UserNamesList)
            {
            
                Get-UserInfoIndividualV2 $server $name "name" $dir_final
                #Get-ADUser -Server $server -Filter "Name -eq '$name'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append
            }
            Write-Host "Successfully exported " $successfulLines " lines to " $dir_final
        }

        #This loop uses the syntax of samaccountname OR LogonName (aka UserPrincipalName).
        elseif($search_type -eq 3)
        {        
            Write-Host "Warning: This mode may return duplicates lines and errors. The output must be filtered down!"    
            foreach ($name in $UserNamesList)
            {
                Get-UserInfoIndividualV2 $server $name "multi" $dir_final
            }
            #Write-Host "Successfully exported " $successfulLines " lines to " $dir_final
        }
        else
        {
            #If an Advanced User types in a field name for a batch search, they can attempt to search for it instead of typing 1, 2, or 3.
            foreach ($name in $UserNamesList)
            {       
                Get-UserInfoIndividualV2 $server $name $search_type $dir_final
                #Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -Append -NoTypeInformation -Encoding UTF8     
            }
            Write-Host "improper search_type parameter entered. Please select 1 for username syntax or 2 for LastName, FirstName syntax."
        }
    }     
}#end of Get-UserInfoBatchV2 function.



Function Get-UserInfoIndividual{
#This provides error checking in case we don't find the user, or have a server issue.

    #MIGHT HAVE TO SETUP PARAMS, NOT SURE ON GLOBAL SCOPE
    Param ($server, $samaccountname, $dir_final)

    $nameReturned = Get-ADUser -Server $server -Filter {samaccountname -eq $samaccountname} -Properties samaccountname | select samaccountname
    if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
    {
        #This part pipes the information to csv
        Get-ADUser -Server $server -Filter {samaccountname -eq $samaccountname} -Properties samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,memberOf |select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append
        $displayNameReturned = Get-ADUser -Server $server -Filter {samaccountname -eq $samaccountname} -Properties displayname | select -ExpandProperty displayname

    
        #Gets sorted MemberOf from list of MemberOf
        [string]$groupsReturned= Get-ADUser -Server $server -Filter {samaccountname -eq $samaccountname} -Properties memberOf| select -ExpandProperty memberOf
        $ArrayOfString = $groupsReturned -split ","
        $ArraySorted = ($ArrayOfString | sort)
        
        [System.Collections.ArrayList]$finalArrayList = "", "CN Only MemberOf List" #gives a heading for index[0] in ArrayList

        #"`rSorted Member Groups" | Out-File -FilePath $dir_final -Append
        #$ArraySorted | Out-File -FilePath $dir_final -Append
    
        #Will add the values tha tcontain "CN" to our finalArrayList    
        Foreach ($i in $ArraySorted)
        {
            if($i.Contains("CN"))
                {
                    $finalArrayList.Add($i) | out-null #this keeps the ArrayList.Add from echoing to PowerShell each line.                    
                }    
        }

        #Writes finalArrayList to file
        $finalArrayList | Out-File -FilePath $dir_final -Append
        

        #Output when successful
        $str_output = "`nUser " + $samaccountname + " named [" + $displayNameReturned + "] successfully found on " + $server + " and exported to " + $dir_final + "`n"
        Write-Host $str_output
    }
    else 
    {
        #Output when unsuccessful
        $str_output = "`nUser " + $samaccountname + " not found on " + $server + "! Please try again." + "`n"
        Write-Host $str_output
    }
}


Function Get-UserInfoBatch{
    #This code simply append the information of all users into a new .csv file at the path.
    Param ($server, $name_list_path, $dir_final, $search_type)

    $UserNamesList = get-content -path $name_list_path    #uses the inputted path to grab names line by line.
    $successfulLines = 0

    #This loop uses the Username syntax by samaccountname
    if($search_type -eq 1)
    {
        foreach ($name in $UserNamesList)
        {
            $nameReturned = Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties samaccountname | select samaccountname
            if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
            {
                $successfulLines += 1
            }
            #old old version, might be useful
            #Get-ADUser -Server $server $name -properties * | select GivenName, Surname, SamAccountName, EmailAddress, Title, Company, Department, Country, st, Office, OfficePhone, MobilePhone, LastLogonDate, createTimeStamp, Enabled | Export-CSV $ExportPath -Append -NoTypeInformation
            
            #V1 version, worked but changing to use Filter for clarity.
            #Get-ADUser -Server $server $name -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -Append -NoTypeInformation -Encoding UTF8
            Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append

        }
        Write-Host "Successfully exported " $successfulLines " lines to " $dir_final
    }

    #this loop uses the syntax of "Last Name, First Name" as appearing in Active Directory. ex. "Smith, John"
    elseif($search_type -eq 2)
    {            
        foreach ($name in $UserNamesList)
        {
            $nameReturned = Get-ADUser -Server $server -Filter {Name -eq $name} -Properties Name | select Name
            if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
            {
                $successfulLines += 1
            }

            Get-ADUser -Server $server -Filter "Name -eq '$name'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -Append -NoTypeInformation -Encoding UTF8 -Append
        }
        Write-Host "Successfully exported " $successfulLines " lines to " $dir_final
    }

    #This loop uses the syntax of samaccountname OR LogonName (aka UserPrincipalName).
    elseif($search_type -eq 3)
    {        
        Write-Host "Warning: This mode may return duplicates lines and errors. The output must be filtered down!"    
        foreach ($name in $UserNamesList)
        {
            #These 4 checks increment the successfulLines amount if anyone is found on the server.
            $nameReturned = Get-ADUser -Server $server -Filter {samaccountname -eq $name} -Properties samaccountname | select samaccountname
            if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
            {
                $successfulLines += 1
            }
            $nameReturned = Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server1.com'" -Properties samaccountname | select samaccountname
            if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
            {
                $successfulLines += 1
            }
            $nameReturned = Get-ADUser -Server $server "UserPrincipalName -eq '$name@peoples-gas.com'" -Properties samaccountname | select samaccountname
            if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
            {
                $successfulLines += 1
            }
            $nameReturned = Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server2.com'" -Properties samaccountname | select samaccountname
            if ( ($nameReturned -ne $null) -and ($nameReturned -ne ""))
            {
                $successfulLines += 1
            }            
            Get-ADUser -Server $server $name -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
            Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server1.com'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name="MemberOf";expression={$_.memberof -join ";"}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
            Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@peoples-gas.com'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name="MemberOf";expression={$_.memberof -join ";"}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
            Get-ADUser -Server $server -Filter "UserPrincipalName -eq '$name@server2.com'" -Properties * | select-object samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name="MemberOf";expression={$_.memberof -join ";"}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
            
            Write-Host "made it here for "$name
        }
        Write-Host "Successfully exported " $successfulLines " lines to " $dir_final
    }
    else
    {
        Write-Host "improper search_type parameter entered. Please select 1 for username syntax or 2 for LastName, FirstName syntax."
    }
           
}



#####Main Code Starts Here #####
$continue = $true

while($continue -eq $true){

    #This is a test of the new V2 Function
        
    $server_temp = "PUTYOURSERVERHERE.com"
    $filter_on_temp = "samaccountname"
    
    
    $name_list_path = ""
    $UserNamesList =""
    $search_type = 0    
    $current_date = Get-Date -Format "MM-dd-yyyy" #ex. 01-01-2021
    $server = "PUTYOURSERVERHERE.com" #can be alternatively changed to your server
    $samaccountname = Read-Host "Enter the username to search, or type 'list' to use a list of names."
    if($samaccountname -eq "list")
    {
        $name_list_path = Read-Host "Please enter a full file path to a text file list with 1 username per line"
        $search_type = Read-Host "Type 1 for a list of usernames, 2 for a list of Names in 'LastName, FirstName' format, 3 for a MIX of Usernames, LogonNames (aka UserPrincipalName), and Names. `r`n(Advanced) Alternatively you can type your own field" 
    }
    
    $server_typed = Read-Host "Type a domain name, or leave blank for" $server ". You can alternatively type 1 for first server, or 2 for second server, or multi to search both servers."
    $dir_final = "\\path\to\here"
    $dir_typed = Read-Host "Enter a directory to save the export in the form C:\Users\Name\Desktop or leave blank to save to " $dir_final
    

    if( ($dir_typed -ne "") -and ($dir_typed -ne " ")) #user typed in a path
    {

        if(!$dir_typed.EndsWith("\"))  #checks for baskslash at the end
        {
            $dir_typed += "\"   #fixes the path so that it ends with a backslash
        }
        $dir_final = $dir_typed + $samaccountname + " - " + $current_date + ".csv"
    }
    else #user typed blank input
    {
        $dir_final += $samaccountname + " - " + $current_date + ".csv"
    }

    if( ($server_typed -ne "") -and ($server_typed -ne " ")) #check for blank input
    {
        $server = $server_typed
    }

    #Switch for changing the value from 1 and 2 for easy access of the domains. 
    switch($server_typed)
    {
    1{ $server = "server1.com"}
    2{ $server = "server2.com"}
    "multi"{ $server = "multi"}
    }
    
    
    #This will grab Individual Info OR Batch Info depending on what the user types.
       
    #user input "list." The Get-UserInfoBatchV2 method can handle "multi" param for servers. 
    if($samaccountname -eq "list")
    {
       Get-UserInfoBatchV2 $server $name_list_path $search_type $dir_final
    }

    #not a list but contains multiple servers
    elseif($server -eq "multi")
    {
        Get-UserInfoMultiServer $server $samaccountname "samaccountname" $dir_final
        Write-Host "Finished multi-search output to" $dir_final
    } 

    #not a list, not multiple servers
    else
    {
        #runs the function to output to the csv for a single name
        Get-UserInfoIndividualV2 $server $samaccountname "samaccountname" $dir_final
        
        $CNInput = Read-Host "Would you like a clean list of MemberOf for CN to be added to the output CSV? Type y/n"
        if($CNInput -eq "y")
        {
            Get-FilteredMemberOf $server $samaccountname $dir_final
        }
       
    }

    $status_input = Read-Host "Press Enter to continue searching or type 'end' to end"
    if($status_input -eq "end")
    {
    $continue = $false
    }

    
    Write-Host "`n" #new line separation for cleanliness
}
