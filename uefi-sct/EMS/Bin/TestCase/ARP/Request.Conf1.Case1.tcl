# 
#  Copyright 2006 - 2010 Unified EFI, Inc.<BR> 
#  Copyright (c) 2010, Intel Corporation. All rights reserved.<BR>
# 
#  This program and the accompanying materials
#  are licensed and made available under the terms and conditions of the BSD License
#  which accompanies this distribution.  The full text of the license may be found at 
#  http://opensource.org/licenses/bsd-license.php
# 
#  THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
#  WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
# 
################################################################################
CaseLevel         CONFORMANCE
CaseAttribute     AUTO
CaseVerboseLevel  DEFAULT

#
# test case Name, category, description, GUID...
#
CaseGuid        AAD18417-51D0-4f7e-8A86-52940EB1977F
CaseName        Request.Conf1.Case1
CaseCategory    ARP
CaseDescription {This case is to test the EFI_INVALID_PARAMETER conforamce of  \
	               ARP.Request}
################################################################################

#
# Begin log ...
#
BeginLog

Include ARP/include/Arp.inc.tcl

set hostmac    [GetHostMac]
set targetmac  [GetTargetMac]

VifUp 0 172.16.210.162 255.255.255.0
BeginScope _ARP_SPEC_CONFORMANCE_

UINTN                            R_Status
UINTN                            R_Handle
EFI_IP_ADDRESS                   R_StationAddress
EFI_ARP_CONFIG_DATA              R_ArpConfigData
EFI_IP_ADDRESS                   R_TargetSwAddress
UINTN                            R_ResolvedEvent
EFI_MAC_ADDRESS                  R_TargetHwAddress
UINTN                            R_EventContext

ArpServiceBinding->CreateChild "&@R_Handle, &@R_Status"
GetAck
SetVar     [subst $ENTS_CUR_CHILD]  @R_Handle
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "ArpSBP.CreateChild - Create Child 1"                          \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetIpv4Address R_StationAddress.v4     "172.16.210.102"
SetVar R_ArpConfigData.SwAddressType   0x800
SetVar R_ArpConfigData.SwAddressLength 4
SetVar R_ArpConfigData.StationAddress  &@R_StationAddress
SetVar R_ArpConfigData.EntryTimeOut    0
SetVar R_ArpConfigData.RetryCount      0
SetVar R_ArpConfigData.RetryTimeOut    0

Arp->Configure {&@R_ArpConfigData, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Arp.Configure - Config Child 1"                               \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetIpv4Address R_TargetSwAddress.v4 "172.16.210.161"
SetEthMacAddress R_TargetHwAddress  "00:02:03:04:05:06"

Arp->Add {FALSE, &@R_TargetSwAddress, &@R_TargetHwAddress, 0, TRUE, &@R_Status}
GetAck

set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Arp.Add - Add normal entry"                                   \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetVar R_EventContext 0
BS->CreateEvent "$EVT_NOTIFY_SIGNAL, $EFI_TPL_CALLBACK, 1, &@R_EventContext,   \
                  &@R_ResolvedEvent, &@R_Status"
GetAck

#
# Check point
#
Arp->Request {&@R_TargetSwAddress, @R_ResolvedEvent, NULL, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_INVALID_PARAMETER]
RecordAssertion $assert $ArpRequestConfAssertionGuid001                        \
                "Arp.Request - with HwAddress invalid"                         \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_INVALID_PARAMETER"

BS->CloseEvent "@R_ResolvedEvent, &@R_Status"
GetAck

#
# Check point
#
Arp->Request {&@R_TargetSwAddress, 0, NULL, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_INVALID_PARAMETER]
RecordAssertion $assert $ArpRequestConfAssertionGuid002                        \
                "Arp.Request - with HwAddress invalid"                         \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_INVALID_PARAMETER"
#
# Check point
#
Arp->Request {NULL, 0, NULL, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_INVALID_PARAMETER]
RecordAssertion $assert $ArpRequestConfAssertionGuid003                        \
                "Arp.Request - with HwAddress invalid"                         \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_INVALID_PARAMETER"

Arp->Delete {TRUE, NULL, &@R_Status}
GetAck

Arp->Delete {FALSE, NULL, &@R_Status}
GetAck

ArpServiceBinding->DestroyChild {@R_Handle, &@R_Status}
GetAck

EndScope _ARP_SPEC_CONFORMANCE_
VifDown 0

#
# End Log
#
EndLog