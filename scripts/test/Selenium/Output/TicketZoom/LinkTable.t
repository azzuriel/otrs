# --
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # disable 'Ticket Information', 'Customer Information' and 'Linked Objects' widgets in AgentTicketZoom screen
        for my $WidgetDisable (qw(0100-TicketInformation 0200-CustomerInformation 0300-LinkTable)) {
            $Helper->ConfigSettingChange(
                Valid => 0,
                Key   => "Ticket::Frontend::AgentTicketZoom###Widgets###$WidgetDisable",
                Value => '',
            );
        }

        # set 'Linked Objects' widget to simple view
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'LinkObject::ViewMode',
            Value => 'Simple',
        );

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create three test tickets
        my @TicketTitles;
        my @TicketIDs;
        for my $TicketCreate ( 1 .. 3 ) {
            my $TicketTitle = "Title" . $Helper->GetRandomID();
            my $TicketID    = $TicketObject->TicketCreate(
                Title      => $TicketTitle,
                Queue      => 'Raw',
                Lock       => 'unlock',
                Priority   => '3 normal',
                State      => 'open',
                CustomerID => 'SeleniumCustomer',
                OwnerID    => 1,
                UserID     => 1,
            );
            $Self->True(
                $TicketID,
                "TicketID $TicketID is created",
            );
            push @TicketTitles, $TicketTitle;
            push @TicketIDs,    $TicketID;
        }

        # get link object
        my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

        # link first and second ticket as parent-child
        my $Success = $LinkObject->LinkAdd(
            SourceObject => 'Ticket',
            SourceKey    => $TicketIDs[0],
            TargetObject => 'Ticket',
            TargetKey    => $TicketIDs[1],
            Type         => 'ParentChild',
            State        => 'Valid',
            UserID       => 1,
        );
        $Self->True(
            $Success,
            "TickedID $TicketIDs[0] and $TicketIDs[1] linked as parent-child"
        );

        # link second and third ticket as parent-child
        $Success = $LinkObject->LinkAdd(
            SourceObject => 'Ticket',
            SourceKey    => $TicketIDs[1],
            TargetObject => 'Ticket',
            TargetKey    => $TicketIDs[2],
            Type         => 'ParentChild',
            State        => 'Valid',
            UserID       => 1,
        );
        $Self->True(
            $Success,
            "TickedID $TicketIDs[1] and $TicketIDs[2] linked as parent-child"
        );

        # create and login test user
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to AgentTicketZoom for test created second ticket
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketIDs[1]");

        # verify it is right screen
        $Self->True(
            index( $Selenium->get_page_source(), $TicketTitles[1] ) > -1,
            "Ticket $TicketTitles[1] found on page",
        );

        # verify there is no 'Linked Objects' widget, it's disabled
        $Self->True(
            index( $Selenium->get_page_source(), "Linked Objects" ) == -1,
            "Linked Objects widget is disabled",
        );

        # reset 'Linked Objects' widget sysconfig, enable it and refresh screen
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Frontend::AgentTicketZoom###Widgets###0300-LinkTable',
            Value => {
                Module => 'Kernel::Output::HTML::TicketZoom::LinkTable',
            },
        );

        $Selenium->VerifiedRefresh();

        # verify there is 'Linked Objects' widget, it's enabled
        $Self->Is(
            $Selenium->find_element( '.Header>h2', 'css' )->get_text(),
            'Linked Objects',
            'Linked Objects widget is enabled',
        );

        # verify there is link to parent ticket
        $Self->True(
            $Selenium->find_elements(
                "//a[contains(\@class, 'LinkObjectLink')][contains(\@title, '$TicketTitles[0]')][contains(\@href, 'TicketID=$TicketIDs[0]')]"
            ),
            "Link to parent ticket found",
        );

        # verify there is link to child ticket
        $Self->True(
            $Selenium->find_elements(
                "//a[contains(\@class, 'LinkObjectLink')][contains(\@title, '$TicketTitles[2]')][contains(\@href, 'TicketID=$TicketIDs[2]')]"
            ),
            "Link to child ticket found",
        );

        # verify there is no collapsed elements on the screen
        $Self->True(
            $Selenium->find_element("//div[contains(\@class, 'WidgetSimple DontPrint Expanded')]"),
            "Linked Objects Widget is expanded",
        );

        # toggle to collapse 'Linked Objects' widget
        $Selenium->find_element("//a[contains(\@title, 'Show or hide the content' )]")->VerifiedClick();

        # verify there is collapsed element on the screen
        $Self->True(
            $Selenium->find_element("//div[contains(\@class, 'WidgetSimple DontPrint Collapsed')]"),
            "Linked Objects Widget is collapsed",
        );

        # verify 'Linked Objects' widget is in the side bar with simple view
        $Self->Is(
            $Selenium->find_element( '.SidebarColumn .Header>h2', 'css' )->get_text(),
            'Linked Objects',
            'Linked Objects widget is positioned in the side bar with simple view',
        );

        # change view to complex
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'LinkObject::ViewMode',
            Value => 'Complex',
        );

        # navigate to AgentTicketZoom for test created second ticket again
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketIDs[1]");

        # Verify 'Linked Object' widget is in the main column with complex view.
        $Self->Is(
            $Selenium->find_element( '.ContentColumn #WidgetTicket .Header>h2', 'css' )->get_text(),
            'Linked: Ticket',
            'Linked Objects widget is positioned in the main column with complex view',
        );

        # cleanup test data
        # delete test created tickets
        for my $TicketDelete (@TicketIDs) {
            $Success = $TicketObject->TicketDelete(
                TicketID => $TicketDelete,
                UserID   => 1,
            );
            $Self->True(
                $Success,
                "TicketID $TicketDelete is deleted",
            );
        }

        # make sure the cache is correct
        for my $Cache (qw(Ticket LinkObject)) {
            $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
                Type => $Cache,
            );
        }

    }

);

1;
