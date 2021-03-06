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
CaseLevel         FUNCTION
CaseAttribute     AUTO
CaseVerboseLevel  DEFAULT

#
# test case Name, category, description, GUID...
#
CaseGuid          0F0556BD-8FBB-458c-B821-E894EAB93F6F
CaseName          CongestionCtrl.Func1.Case3
CaseCategory      TCP
CaseDescription   {This item is to test the [EUT] correctly performs the slow  \
                   start and congestion avoidance algorithms when SYN segment  \
                   timeout causes congestion.}
################################################################################

Include TCP4/include/Tcp4.inc.tcl

proc CleanUpEutEnvironment {} {
  global RST
 
  UpdateTcpSendBuffer TCB -c $RST
  SendTcpPacket TCB
 
  DestroyTcb
  DestroyPacket
  DelEntryInArpCache

  Tcp4ServiceBinding->DestroyChild "@R_Tcp4Handle, &@R_Status"
  GetAck
 
  Tcp4ServiceBinding->DestroyChild "@R_Accept_NewChildHandle, &@R_Status"
  GetAck

  BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
  GetAck
  BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
  GetAck

  EndLogPacket
  EndScope _TCP4_RFC_COMPATIBILITY_
  EndLog
}

#
# Begin log ...
#
BeginLog

#
# BeginScope on OS.
#
BeginScope _TCP4_RFC_COMPATIBILITY_

BeginLogPacket CongestionCtrl.Func1.Case4 "host $DEF_EUT_IP_ADDR and host      \
                                                $DEF_ENTS_IP_ADDR"

#
# Parameter Definition
# R_ represents "Remote EFI Side Parameter"
# L_ represents "Local OS Side Parameter"
#
set    L_FragmentLength          5120

UINTN                            R_Status
UINTN                            R_Tcp4Handle
UINTN                            R_Context

EFI_TCP4_ACCESS_POINT            R_Configure_AccessPoint
EFI_TCP4_CONFIG_DATA             R_Configure_Tcp4ConfigData

EFI_TCP4_COMPLETION_TOKEN        R_Connect_CompletionToken
EFI_TCP4_CONNECTION_TOKEN        R_Connect_ConnectionToken

EFI_TCP4_COMPLETION_TOKEN        R_Accept_CompletionToken
EFI_TCP4_LISTEN_TOKEN            R_Accept_ListenToken
UINTN                            R_Accept_NewChildHandle

EFI_TCP4_IO_TOKEN                R_Transmit_IOToken
EFI_TCP4_COMPLETION_TOKEN        R_Transmit_CompletionToken

Packet                           R_Packet_Buffer
EFI_TCP4_TRANSMIT_DATA           R_TxData
EFI_TCP4_FRAGMENT_DATA           R_FragmentTable
CHAR8                            R_FragmentBuffer($L_FragmentLength)

#
# Initialization of TCB related on OS side.
#
CreateTcb TCB $DEF_ENTS_IP_ADDR $DEF_ENTS_PRT $DEF_EUT_IP_ADDR $DEF_EUT_PRT
BuildTcpOptions MssOption -m 256
CreatePayload OneBytePayload  Data 1  0x01

LocalEther  $DEF_ENTS_MAC_ADDR
RemoteEther $DEF_EUT_MAC_ADDR
LocalIp     $DEF_ENTS_IP_ADDR
RemoteIp    $DEF_EUT_IP_ADDR

#
# Add an entry in ARP cache.
#
AddEntryInArpCache

#
# Create Tcp4 Child.
#
Tcp4ServiceBinding->CreateChild "&@R_Tcp4Handle, &@R_Status"
GetAck
SetVar     [subst $ENTS_CUR_CHILD]  @R_Tcp4Handle
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4SBP.CreateChild - Create Child 1."                        \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# Configure TCP instance.
#
SetVar R_Configure_AccessPoint.UseDefaultAddress      FALSE
SetIpv4Address R_Configure_AccessPoint.StationAddress $DEF_EUT_IP_ADDR
SetIpv4Address R_Configure_AccessPoint.SubnetMask     $DEF_EUT_MASK
SetVar R_Configure_AccessPoint.StationPort            $DEF_EUT_PRT
SetIpv4Address R_Configure_AccessPoint.RemoteAddress  $DEF_ENTS_IP_ADDR
SetVar R_Configure_AccessPoint.RemotePort             $DEF_ENTS_PRT
SetVar R_Configure_AccessPoint.ActiveFlag             FALSE

SetVar R_Configure_Tcp4ConfigData.TypeOfService       0
SetVar R_Configure_Tcp4ConfigData.TimeToLive          128
SetVar R_Configure_Tcp4ConfigData.AccessPoint         @R_Configure_AccessPoint
SetVar R_Configure_Tcp4ConfigData.ControlOption       0

Tcp4->Configure {&@R_Configure_Tcp4ConfigData, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4.Configure - Configure Child 1."                          \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# Call Tcp4.Accept for an passive TCP instance.
#
BS->CreateEvent "$EVT_NOTIFY_SIGNAL, $EFI_TPL_CALLBACK, 1, &@R_Context,        \
                 &@R_Accept_CompletionToken.Event, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "BS.CreateEvent."                                              \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetVar R_Accept_NewChildHandle 0
SetVar R_Accept_ListenToken.CompletionToken @R_Accept_CompletionToken
SetVar R_Accept_ListenToken.CompletionToken.Status $EFI_INCOMPATIBLE_VERSION

Tcp4->Accept {&@R_Accept_ListenToken, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4.Accept - Open an passive connection."                    \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# Handles the three-way handshake. Configure the [OS] to ignore the first SYN
# segment and wait for the ConnectionTimeout seconds. When received the second
# SYN segment, make the [OS] send back the SYN, ACK segment.
#
UpdateTcpSendBuffer TCB -c $SYN -o MssOption
SendTcpPacket TCB

ReceiveTcpPacket TCB 5
ReceiveTcpPacket TCB 5

UpdateTcpSendBuffer TCB -c $ACK
SendTcpPacket TCB

#
# Get the NewChildHandle value.
#
GetVar R_Accept_ListenToken.NewChildHandle
SetVar R_Accept_NewChildHandle ${R_Accept_ListenToken.NewChildHandle}
SetVar [subst $ENTS_CUR_CHILD]  @R_Accept_NewChildHandle

#
# Call Tcp4.Transmit to transmit a packet.
#
BS->CreateEvent "$EVT_NOTIFY_SIGNAL, $EFI_TPL_CALLBACK, 1, &@R_Context,        \
                 &@R_Transmit_CompletionToken.Event, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "BS.CreateEvent."                                              \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetVar R_TxData.Push                      FALSE
SetVar R_TxData.Urgent                    FALSE
SetVar R_TxData.DataLength                $L_FragmentLength
SetVar R_TxData.FragmentCount             1

SetVar R_FragmentTable.FragmentLength     $L_FragmentLength
SetVar R_FragmentTable.FragmentBuffer     &@R_FragmentBuffer
SetVar R_TxData.FragmentTable(0)          @R_FragmentTable

SetVar R_Packet_Buffer.TxData  &@R_TxData

SetVar R_Transmit_IOToken.CompletionToken @R_Transmit_CompletionToken
SetVar R_Transmit_IOToken.CompletionToken.Status $EFI_INCOMPATIBLE_VERSION
SetVar R_Transmit_IOToken.Packet_Buffer   @R_Packet_Buffer

Tcp4->Transmit {&@R_Transmit_IOToken, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $CongestionCtrlFunc1AssertionGuid003                   \
                "Tcp4.Transmit - Transmit a packet."                           \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# OS get the transmitted data packet and interact with EUT to expand the cwnd.
#
set expect_r_seq 1
set expect_r_len 256
set expect_data_seg_num 1
set expect_next_seq [expr ${TCB.r_isn} + $expect_r_len + 1]

for { set i 0} { $i < 20 } { incr i } {
  for { set j 0} { $j < $expect_data_seg_num } { incr j } {
    ReceiveTcpPacket TCB 2
    if { ${TCB.received} == 1 } {
      if { ${TCB.r_f_ack} != 1 } {
        set assert fail
        RecordAssertion $assert $GenericAssertionGuid                          \
                        "EUT doesn't send out the data segment correctly."
        CleanUpEutEnvironment
        return
      } else {
          if { ${TCB.r_seq} != $expect_r_seq || ${TCB.r_ack} != 1} {
            set assert fail
            RecordAssertion $assert $GenericAssertionGuid                      \
                             "The sequence number or acknowledge number of the \
                              data segment is not correct."
            CleanUpEutEnvironment
            return
          }
          if { ${TCB.r_len} != $expect_r_len } {
            set assert fail
            RecordAssertion $assert $GenericAssertionGuid                      \
                            "The data length of the data segment is not correct"
            CleanUpEutEnvironment
            return
          }
          set expect_r_seq [expr $expect_r_seq + $expect_r_len]
        }
      set assert pass
      RecordAssertion $assert $GenericAssertionGuid                            \
                      "The EUT send out the data segment correctly."
    } else {
      set assert fail
      RecordAssertion $assert $GenericAssertionGuid                            \
                      "EUT doesn't send out any segment."
      CleanUpEutEnvironment
      return
    }
  }
  UpdateTcpSendBuffer TCB -c $ACK -a $expect_next_seq
  SendTcpPacket TCB
  set expect_next_seq [expr $expect_next_seq + $expect_r_len]
}

#
# Check the token status of Tranmist interface.
#
while {1 > 0} {
  Stall 1
  GetVar R_Transmit_IOToken.CompletionToken.Status
 
  if { ${R_Transmit_IOToken.CompletionToken.Status} != $EFI_INCOMPATIBLE_VERSION} {
    if { ${R_Transmit_IOToken.CompletionToken.Status} != $EFI_SUCCESS} {
      set assert fail
      RecordAssertion $assert $GenericAssertionGuid                            \
                      "Transmit data segment error."                           \
                      "ReturnStatus - ${R_Transmit_IOToken.CompletionToken.Status},\
                       ExpectedStatus - $EFI_SUCCESS"
      CleanUpEutEnvironment
      return
    } else {
      RecordAssertion $assert $GenericAssertionGuid                            \
                              "Transmit data segment successfully."            \
                              "ReturnStatus - ${R_Transmit_IOToken.CompletionToken.Status},\
                               ExpectedStatus - $EFI_SUCCESS"
      break
    }
  }
}

#
# Clean up the environment on EUT side.
#

CleanUpEutEnvironment

