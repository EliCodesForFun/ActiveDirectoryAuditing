# ActiveDirectoryAuditing


This PowerShell script will let you do a batch audit of a server you specify for the $server variable.
Basically, you can output the information of any users you need to get information on, from Active Directory.
This good for Sys Admin work and can save you a lot of time, as you can feed it a list of names in the format:

```
Smith, John
Gates, Bill
Douglas, Michael
```
In a text file, and it will search for those names, and provide you with their account information.
The account info will include the Account Status (enabled/disabled), email address, account expiration date, description.

The full list of attributes:
```
samaccountname,emailaddress,UserPrincipalName,displayname,enabled,department,company,manager,city,state,distinguishedName,description,AccountExpirationDate,@{name=”MemberOf”;expression={$_.memberof -join “;”}} | Export-CSV $dir_final -NoTypeInformation -Encoding UTF8 -Append 
```
I have cleaned the MemberOf information so that it appears on 1 line when output to a csv.



I used this for work, so it will need a bit of modification to work with your company's domain.
I recommend changing every instance of "server1.com" to whatever domain your company uses.
For example, if you worked at Google, you would change it to "google.com."
In some instances, it searches for <samaccountname>@server1.com so you'd want to search for something like jsmith@google.com in practice.

There's a text user interface, where you'll select the server, specify individual or list, give it a directory for a list (if you want a list), and you can specify the output directory.

You have to specify directories in the text interface without using quotes " " - you'll have to write in some code in order to properly handle the check for whether quotes were inputted.


