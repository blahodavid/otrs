# --
# Kernel/Modules/AdminQueueResponses.pm - queue <-> responses
# Copyright (C) 2001-2007 OTRS GmbH, http://otrs.org/
# --
# $Id: AdminQueueResponses.pm,v 1.18 2007-01-20 22:03:07 mh Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AdminQueueResponses;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.18 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # get common opjects
    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check all needed objects
    foreach (qw(ParamObject DBObject LayoutObject ConfigObject LogObject)) {
        if (!$Self->{$_}) {
            $Self->{LayoutObject}->FatalError(Message => "Got no $_!");
        }
    }

    return $Self;
}

sub Run {
    my $Self = shift;
    my %Param = @_;
    my $Output = '';
    my $Subaction = $Self->{Subaction};
    my $UserID = $Self->{UserID};
    my $ID = $Self->{ParamObject}->GetParam(Param => 'ID') || '';
    $ID = $Self->{DBObject}->Quote($ID, 'Integer') if ($ID);
    my $NextScreen = 'AdminQueueResponses';

    # user <-> group 1:n
    if ($Subaction eq 'Response') {
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar(Type => 'Admin');
        # get StdResponses data
        my %StdResponsesData = $Self->{DBObject}->GetTableData(
            Table => 'standard_response',
            What => 'id, name',
            Where => "id = $ID",
        );
        # get queue data
        my %QueueData = $Self->{DBObject}->GetTableData(
            Table => 'queue',
            What => 'id, name',
            Valid => 1
        );
        my %Data = $Self->{DBObject}->GetTableData(
            Table => 'queue_standard_response',
            What => 'queue_id, standard_response_id',
            Where => "standard_response_id = $ID"
        );
        $Output .= $Self->_Mask(
            FirstData => \%StdResponsesData,
            SecondData => \%QueueData,
            Data => \%Data,
            Type => 'Response',
        );

        $Output .= $Self->{LayoutObject}->Footer();
    }
    # group <-> user n:1
    elsif ($Subaction eq 'Queue') {
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar(Type => 'Admin');
        # get StdResponses data
        my %StdResponsesData = $Self->{DBObject}->GetTableData(
            Table => 'standard_response',
            What => 'id, name',
            Valid => 1
        );
        # get queue data
        my %QueueData = $Self->{DBObject}->GetTableData(
            Table => 'queue',
            What => 'id, name',
            Where => "id = $ID",
        );
        my %Data = $Self->{DBObject}->GetTableData(
            Table => 'queue_standard_response',
            What => 'standard_response_id, queue_id',
            Where => "queue_id = $ID"
        );
        $Output .= $Self->_Mask(
            FirstData => \%QueueData,
            SecondData => \%StdResponsesData,
            Data => \%Data,
            Type => 'Queue',
        );
        $Output .= $Self->{LayoutObject}->Footer();
    }
    # queues to standard_responses
    elsif ($Subaction eq 'ChangeQueue') {
        my @NewIDs = $Self->{ParamObject}->GetArray(Param => 'IDs');
        $Self->{DBObject}->Do(SQL => "DELETE FROM queue_standard_response WHERE queue_id = $ID");

        foreach my $NewID (@NewIDs) {
            # db quote
            $NewID = $Self->{DBObject}->Quote($NewID, 'Integer');
            my $SQL = "INSERT INTO queue_standard_response (queue_id, standard_response_id, create_time, create_by, " .
                " change_time, change_by)" .
                " VALUES " .
                " ($ID, $NewID, current_timestamp, $UserID, current_timestamp, $UserID)";
            $Self->{DBObject}->Do(SQL => $SQL);
        }
        $Output .= $Self->{LayoutObject}->Redirect(OP => "Action=$NextScreen");
    }
    # standard_responses top queues
    elsif ($Subaction eq 'ChangeResponse') {
        my @NewIDs = $Self->{ParamObject}->GetArray(Param => 'IDs');
        $Self->{DBObject}->Do(SQL => "DELETE FROM queue_standard_response WHERE standard_response_id = $ID");
        foreach my $NewID (@NewIDs) {
            # db quote
            $NewID = $Self->{DBObject}->Quote($NewID, 'Integer');
            my $SQL = "INSERT INTO queue_standard_response (queue_id, standard_response_id, create_time, create_by, " .
                " change_time, change_by)" .
                " VALUES " .
                " ($NewID, $ID, current_timestamp, $UserID, current_timestamp, $UserID)";
            $Self->{DBObject}->Do(SQL => $SQL);
        }
        $Output .= $Self->{LayoutObject}->Redirect(OP => "Action=$NextScreen");
    }
    # else ! print form
    else {
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar(Type => 'Admin');
        # get StdResponses data
        my %StdResponsesData = $Self->{DBObject}->GetTableData(
            Table => 'standard_response',
            What => 'id, name',
            Valid => 1
        );
        # get queue data
        my %QueueData = $Self->{DBObject}->GetTableData(
            Table => 'queue',
            What => 'id, name',
            Valid => 1
        );
        $Output .= $Self->_MaskFrom(
            FirstData => \%StdResponsesData,
            SecondData => \%QueueData
        );
        $Output .= $Self->{LayoutObject}->Footer();
    }
    return $Output;
}

sub _Mask {
    my $Self = shift;
    my %Param = @_;
    my $FirstData = $Param{FirstData};
    my %FirstDataTmp = %$FirstData;
    my $SecondData = $Param{SecondData};
    my %SecondDataTmp = %$SecondData;
    my $Data = $Param{Data};
    my %DataTmp = %$Data;
    $Param{Type} = $Param{Type} || 'Response';
    my $NeType = 'Response';
    $NeType = 'Queue' if ($Param{Type} eq 'Response');

    foreach (sort keys %FirstDataTmp) {
        $FirstDataTmp{$_} = $Self->{LayoutObject}->Ascii2Html(
            Text => $FirstDataTmp{$_},
            HTMLQuote => 1,
            LanguageTranslation => 0,
        ) || '';
        $Param{OptionStrg0} .= "<B>$Param{Type}:</B> <A HREF=\"$Self->{LayoutObject}->{Baselink}Action=Admin$Param{Type}&Subaction=Change&ID=$_\">" .
            "$FirstDataTmp{$_}</A> (id=$_)<BR>";
        $Param{OptionStrg0} .= "<INPUT TYPE=\"hidden\" NAME=\"ID\" VALUE=\"$_\"><BR>\n";
    }
    $Param{OptionStrg0} .= "<B>$NeType:</B><BR> <SELECT NAME=\"IDs\" SIZE=10 multiple>\n";
    foreach my $ID (sort keys %SecondDataTmp) {
        $SecondDataTmp{$ID} = $Self->{LayoutObject}->Ascii2Html(
            Text => $SecondDataTmp{$ID},
            HTMLQuote => 1,
            LanguageTranslation => 0,
        ) || '';
        $Param{OptionStrg0} .= "<OPTION ";
        foreach (sort keys %DataTmp) {
            if ($_ eq $ID) {
                $Param{OptionStrg0} .= 'selected';
            }
        }
        $Param{OptionStrg0} .= " VALUE=\"$ID\">$SecondDataTmp{$ID} (id=$ID)</OPTION>\n";
    }
    $Param{OptionStrg0} .= "</SELECT>\n";

    return $Self->{LayoutObject}->Output(TemplateFile => 'AdminQueueResponsesChangeForm', Data => \%Param);
}

sub _MaskFrom {
    my $Self = shift;
    my %Param = @_;
    my $UserData = $Param{FirstData};
    my %UserDataTmp = %$UserData;
    my $GroupData = $Param{SecondData};
    my %GroupDataTmp = %$GroupData;
    my $BaseLink = $Self->{LayoutObject}->{Baselink} . "Action=AdminQueueResponses&";

    foreach (sort {$UserDataTmp{$a} cmp $UserDataTmp{$b}} keys %UserDataTmp) {
        $UserDataTmp{$_} = $Self->{LayoutObject}->Ascii2Html(
            Text => $UserDataTmp{$_},
            HTMLQuote => 1,
            LanguageTranslation => 0,
        );
        $Param{AnswerQueueStrg} .= "<a href=\"$BaseLink"."Subaction=Response&ID=$_\">$UserDataTmp{$_}</a><br>";
    }
    foreach (sort {$GroupDataTmp{$a} cmp $GroupDataTmp{$b}} keys %GroupDataTmp) {
        $GroupDataTmp{$_} = $Self->{LayoutObject}->Ascii2Html(
            Text => $GroupDataTmp{$_},
            HTMLQuote => 1,
            LanguageTranslation => 0,
        );
        $Param{QueueAnswerStrg}.= "<a href=\"$BaseLink"."Subaction=Queue&ID=$_\">$GroupDataTmp{$_}</a><br>";
    }

    return $Self->{LayoutObject}->Output(TemplateFile => 'AdminQueueResponsesForm', Data => \%Param);
}

1;