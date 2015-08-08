# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
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

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users', 'time_accounting' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # create another test user
        my $TestUser = $Helper->TestUserCreate();

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUser,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to AgentTimeAccountingSetting
        $Selenium->get("${ScriptAlias}index.pl?Action=AgentTimeAccountingSetting");

        # check time account setting page IDs
        for my $SettingPageID (
            qw(NewUserID FilterProjects FilterTasks FilterUsers Core_UI_AutogeneratedID_0
            Core_UI_AutogeneratedID_1 Core_UI_AutogeneratedID_2)
            )
        {
            my $Element = $Selenium->find_element( "#$SettingPageID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # check buttons
        for my $SettingButton ( 'Add', 'Add task', 'New user' )
        {
            my $Element = $Selenium->find_element("//button[\@value='$SettingButton'][\@type='submit']");
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # click on 'Add project'
        $Selenium->find_element("//button[\@value='Add'][\@type='submit']")->click();

        # check project page IDs
        for my $ProjectPageID (qw(Project ProjectDescription ProjectStatus))
        {
            my $Element = $Selenium->find_element( "#$ProjectPageID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # create test project
        my $ProjectTitle       = 'Project ' . $Helper->GetRandomID();
        my $ProjectDescription = 'Selenium test project';
        $Selenium->find_element( "#Project",            'css' )->send_keys($ProjectTitle);
        $Selenium->find_element( "#ProjectDescription", 'css' )->send_keys($ProjectDescription);
        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->click();

        # verify created test project
        for my $ProjectVerify ( $ProjectTitle, $ProjectDescription ) {
            $Self->True(
                index( $Selenium->get_page_source(), $ProjectVerify ) > -1,
                "$ProjectVerify - found",
            );
        }

        # click on 'Add task'
        $Selenium->find_element("//button[\@value='Add task'][\@type='submit']")->click();

        # check task page IDs
        for my $TaskPageID (qw(Task TaskStatus))
        {
            my $Element = $Selenium->find_element( "#$TaskPageID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # create test task
        my $ActionTitle = 'Task ' . $Helper->GetRandomID();
        $Selenium->find_element( "#Task", 'css' )->send_keys($ActionTitle);
        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->click();

        # verify created test task
        $Self->True(
            index( $Selenium->get_page_source(), $ActionTitle ) > -1,
            "$ActionTitle - found",
        );

        # add test user to time account setting
        my $AutoCompleteUser = "$TestUser $TestUser";
        $Selenium->find_element( "#NewUserID_Search", 'css' )->click();
        sleep 1;
        $Selenium->find_element("//*[text()='$AutoCompleteUser']")->click();
        $Selenium->find_element("//button[\@value='New user'][\@type='submit']")->click();

        # check edit user page
        for my $EditUserPageID (
            qw(Description ShowOvertime CreateProject Calendar DateStart-1 DateEnd-1 LeaveDays-1
            WeeklyHours-1 Overtime-1 PeriodStatus-1)
            )
        {
            my $Element = $Selenium->find_element( "#$EditUserPageID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # click 'Add time period'
        $Selenium->find_element("//button[\@value='Add time period'][\@type='submit']")->click();

        # check for new added time period fields
        for my $NewTimePeriodID (qw(DateStart-2 DateEnd-2 LeaveDays-2 WeeklyHours-2 Overtime-2 PeriodStatus-2))
        {
            my $Element = $Selenium->find_element( "#$NewTimePeriodID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # edit user setting
        my $UserDescription = 'Selenium test user setting';
        $Selenium->find_element( "#Description",   'css' )->clear();
        $Selenium->find_element( "#Description",   'css' )->send_keys($UserDescription);
        $Selenium->find_element( "#ShowOvertime",  'css' )->click();
        $Selenium->find_element( "#CreateProject", 'css' )->click();
        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->click();

        # verify test user setting
        my $SettingUser = "$TestUser $TestUser ($TestUser)";
        for my $SettingUserVerify ( $SettingUser, $UserDescription ) {
            $Self->True(
                index( $Selenium->get_page_source(), $SettingUserVerify ) > -1,
                "$SettingUserVerify - found",
            );
        }

        # get DB object
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # get DB clean-up data
        my @DBCleanData = (
            {
                Quoted  => $ProjectTitle,
                Table   => 'time_accounting_project',
                Where   => 'project',
                Bind    => '',
                Message => "$ProjectTitle - deleted",
            },
            {
                Quoted  => $ActionTitle,
                Table   => 'time_accounting_action',
                Where   => 'action',
                Bind    => '',
                Message => "$ActionTitle - deleted",
            },
            {
                Table   => 'time_accounting_user',
                Where   => 'user_id',
                Bind    => $TestUserID,
                Message => "Test user $TestUserID - removed from accounting setting",
            },
            {
                Table   => 'time_accounting_user_period',
                Where   => 'user_id',
                Bind    => $TestUserID,
                Message => "Test user $TestUserID - removed from accounting period",
            },
        );

        # clean system from test created data
        for my $Delete (@DBCleanData) {
            if ( $Delete->{Quoted} ) {
                $Delete->{Bind} = $DBObject->Quote( $Delete->{Quoted} );
            }
            my $Success = $DBObject->Do(
                SQL  => "DELETE FROM $Delete->{Table} WHERE $Delete->{Where} = ?",
                Bind => [ \$Delete->{Bind} ],
            );
            $Self->True(
                $Success,
                $Delete->{Message},
            );
        }
    }
);

1;