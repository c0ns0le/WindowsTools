﻿#Function Test-Port{  

#region Notes

<#    
.SYNOPSIS    
    Tests port on computer.  
.DESCRIPTION  
    Tests port on computer.  
.PARAMETER computer  
    Name of server to test the port connection on.  
.PARAMETER port  
    Port to test    
.PARAMETER tcp  
    Use tcp port   
.PARAMETER udp  
    Use udp port   
.PARAMETER UDPTimeOut 
    Sets a timeout for UDP port query. (In milliseconds, Default is 1000)    
.PARAMETER TCPTimeOut 
    Sets a timeout for TCP port query. (In milliseconds, Default is 1000)             
.NOTES
	TITLE:      Test-Port.ps1
	VERSION:    1.0.1
	DATE:       04/22/2011
	STATE:		Alpha
	AUTHOR:     Levon Becker (Boe Prox)
	ENV:        Powershell v2
	TOOLS:      PowerGUI Script Editor, RegexBuddy
.LINK    
    https://boeprox.wordpress.org  
.EXAMPLE    
    Test-Port -computer 'server' -port 80  
    Checks port 80 on server 'server' to see if it is Listening  
.EXAMPLE    
    'server' | Test-Port -port 80  
    Checks port 80 on server 'server' to see if it is Listening   
.EXAMPLE    
    Test-Port -computer @("server1","server2") -port 80  
    Checks port 80 on server1 and server2 to see if it is Listening     
.EXAMPLE    
    @("server1","server2") | Test-Port -port 80  
    Checks port 80 on server1 and server2 to see if it is Listening    
.EXAMPLE    
    (Get-Content hosts.txt) | Test-Port -port 80  
    Checks port 80 on servers in host file to see if it is Listening  
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port 80  
    Checks port 80 on servers in host file to see if it is Listening     
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port @(1..59)  
    Checks a range of ports from 1-59 on all servers in the hosts.txt file      
            
#>   

<# Parent Script Dependents

None

#>

<# Dependencies

None

#>

<# Change Log

1.0.0 - 00/00/201x 
	Created.

#>

<# Sources

Original Code
	http://gallery.technet.microsoft.com/ScriptCenter/97119ed6-6fb2-446d-98d8-32d823867131/
    Author: Boe Prox
	https://boeprox.wordpress.org 
    DateCreated: 18Aug2010   
    List of Ports: http://www.iana.org/assignments/port-numbers  

#>
#endregion Notes

[cmdletbinding(  
    DefaultParameterSetName = '',  
    ConfirmImpact = 'low'  
)]  
    Param(  
        [Parameter(  
            Mandatory = $True,  
            Position = 0,  
            ParameterSetName = '',  
            ValueFromPipeline = $True)]  
            [array]$computer,  
        [Parameter(  
            Position = 1,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [array]$port,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$TCPtimeout=1000,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$UDPtimeout=1000,             
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$TCP,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$UDP              
                          
        )  
    Begin {  
        If (!$tcp -AND !$udp) {$tcp = $True}  
        #Typically you never do this, but in this case I felt it was for the benefit of the function  
        #as any errors will be noted in the output of the report          
        $ErrorActionPreference = "SilentlyContinue"  
        $global:test_port_results = @()  
        }  
    Process {     
        ForEach ($c in $computer) {  
            ForEach ($p in $port) {  
                If ($tcp) {    
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes  
                    #Create object for connecting to port on computer  
                    $tcpobject = new-Object ComputerName.Net.Sockets.TcpClient  
                    #Connect to remote machine's port                
                    $connect = $tcpobject.BeginConnect($c,$p,$null,$null)  
                    #Configure a timeout before quitting  
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false)  
                    #If timeout  
                    If(!$wait) {  
                        #Close connection  
                        $tcpobject.Close()  
                        Write-Verbose "Connection Timeout"  
                        #Build report  
                        $temp.Server = $c  
                        $temp.Port = $p  
                        $temp.TypePort = "TCP"  
                        $temp.Open = "False"  
                        $temp.Notes = "Connection to Port Timed Out"  
                        }  
                    Else {  
                        $error.Clear()  
                        $tcpobject.EndConnect($connect) | out-Null  
                        #If error  
                        If($error[0]){  
                            #Begin making error more readable in report  
                            [string]$string = ($error[0].exception).message  
                            $message = (($string.split(":")[1]).replace('"',"")).TrimStart()  
                            $failed = $true  
                            }  
                        #Close connection      
                        $tcpobject.Close()  
                        #If unable to query port to due failure  
                        If($failed){  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = "False"  
                            $temp.Notes = "$message"  
                            }  
                        #Successfully queried port      
                        Else{  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "TCP"  
                            $temp.Open = "True"    
                            $temp.Notes = ""  
                            }  
                        }     
                    #Reset failed value  
                    $failed = $Null      
                    #Merge temp array with report              
                    $global:test_port_results += $temp  
                    }      
                If ($udp) {  
                    #Create temporary holder   
                    $temp = "" | Select Server, Port, TypePort, Open, Notes                                     
                    #Create object for connecting to port on computer  
                    $udpobject = new-Object ComputerName.Net.Sockets.UdpComputerName($p)  
                    #Set a timeout on receiving message 
                    $udpobject.ComputerName.ReceiveTimeout = $UDPTimeout 
                    #Connect to remote machine's port                
                    Write-Verbose "Making UDP connection to remote server" 
                    $udpobject.Connect("$c",$p) 
                    #Sends a message to the host to which you have connected. 
                    Write-Verbose "Sending message to remote host" 
                    $a = new-object ComputerName.text.asciiencoding 
                    $byte = $a.GetBytes("$(Get-Date)") 
                    [void]$udpobject.Send($byte,$byte.length) 
                    #IPEndPoint object will allow us to read datagrams sent from any source.  
                    Write-Verbose "Creating remote endpoint" 
                    $remoteendpoint = New-Object ComputerName.net.ipendpoint([ComputerName.net.ipaddress]::Any,0) 
                     
                    Try { 
                        #Blocks until a message returns on this socket from a remote host. 
                        Write-Verbose "Waiting for message return" 
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
                        [string]$returndata = $a.GetString($receivebytes) 
                        } 
 
                    Catch { 
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                            #Close connection  
                            $udpobject.Close()  
                            #Make sure that the host is online and not a false positive that it is open 
                            If (Test-Connection -comp $c -count 1 -quiet) { 
                                Write-Verbose "Connection Open"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = "True"  
                                $temp.Notes = "" 
                                } 
                            Else { 
                                <# 
                                It is possible that the host is not online or that the host is online,  
                                but ICMP is blocked by a firewall and this port is actually open. 
                                #> 
                                Write-Verbose "Host maybe unavailable"  
                                #Build report  
                                $temp.Server = $c  
                                $temp.Port = $p  
                                $temp.TypePort = "UDP"  
                                $temp.Open = "False"  
                                $temp.Notes = "Unable to verify if port is open or if host is unavailable."                                 
                                }                         
                            } 
                        ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                            #Close connection  
                            $udpobject.Close()  
                            Write-Verbose "Connection Timeout"  
                            #Build report  
                            $temp.Server = $c  
                            $temp.Port = $p  
                            $temp.TypePort = "UDP"  
                            $temp.Open = "False"  
                            $temp.Notes = "Connection to Port Timed Out"                         
                            } 
                        Else { 
                            $udpobject.close() 
                            } 
                        }     
                    #Merge temp array with report              
                    $global:test_port_results += $temp  
                    }                                  
                }  
            }                  
        }  
    End {  
        #Generate Report  
        $global:test_port_results
        }          
#}
