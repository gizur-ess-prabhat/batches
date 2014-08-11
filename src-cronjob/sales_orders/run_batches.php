<?php
/**
 * @category   Cronjobs
 * @package    Integration
 * @subpackage CronJob
 * @author     Prabhat Khera <gizur-ess-prabhat@gizur.com>
 * @version    SVN: $Id$
 * @link       href="http://gizur.com"
 * @license    Commercial license
 * @copyright  Copyright (c) 2012, Gizur AB, 
 * <a href="http://gizur.com">Gizur Consulting</a>, All rights reserved.
 *
 * purpose : Connect to Amazon SQS through aws-php-sdk
 * Coding standards:
 * http://pear.php.net/manual/en/standards.php
 *
 * PHP version 5.3
 *
 */

ini_set('display_errors', 'On');
error_reporting(E_ALL);
$output = null;

if (isset($_GET['action'])) {
    @shell_exec('chmod +x ' . __DIR__ . '/' . $_GET['action'] . '.sh');
    switch ($_GET['action']) {
        case 'setup-tables':            
            $output = shell_exec('' . __DIR__ . '/setup-tables.sh');
            break;
        case 'phpcronjob1':
            $output = shell_exec('' . __DIR__ . '/phpcronjob1.sh');
            break;
        case 'phpcronjob2':
            $output = shell_exec('' . __DIR__ . '/phpcronjob2.sh');
            break;
        case 'phpcronjob3':
            $output = shell_exec('' . __DIR__ . '/phpcronjob3.sh');
            break;
        case 'phpcronjobs':
            /*
             * Cron Job 1
             */
            @shell_exec('chmod +x ' . __DIR__ . '/phpcronjob1.sh');
            $output .= shell_exec('' . __DIR__ . '/phpcronjob1.sh');
            @shell_exec('chmod -x ' . __DIR__ . '/phpcronjob1.sh');
            /*
             * Cron Job 2
             */
            @shell_exec('chmod +x ' . __DIR__ . '/phpcronjob2.sh');
            $output .= shell_exec('' . __DIR__ . '/phpcronjob2.sh');
            @shell_exec('chmod -x ' . __DIR__ . '/phpcronjob2.sh');
            /*
             * Cron Job 3
             */
            @shell_exec('chmod +x ' . __DIR__ . '/phpcronjob3.sh');
            $output .= shell_exec('' . __DIR__ . '/phpcronjob3.sh');
            @shell_exec('chmod -x ' . __DIR__ . '/phpcronjob3.sh');
            break;
        case 'mail_report':  
            @shell_exec('chmod +x ' . __DIR__ . '/../reports/sales_orders.sh');
            $output = shell_exec('' . __DIR__ . '/../reports/sales_orders.sh');
            @shell_exec('chmod -x ' . __DIR__ . '/../reports/sales_orders.sh');
            break;
        case 'mail_report_csv':  
            @shell_exec('chmod +x ' . __DIR__ . '/../reports/sales_orders_csv.sh');
            $output = shell_exec('' . __DIR__ . '/../reports/sales_orders_csv.sh');
            @shell_exec('chmod -x ' . __DIR__ . '/../reports/sales_orders_csv.sh');
            break;
        case 'mail_report_daily':  
            @shell_exec('chmod +x ' . __DIR__ . '/../reports/sales_orders_daily.sh');
            $output = shell_exec('' . __DIR__ . '/../reports/sales_orders_daily.sh');
            @shell_exec('chmod -x ' . __DIR__ . '/../reports/sales_orders_daily.sh');
            break;
        case 'phpinfo':
            phpinfo();
            break;
    }
    @shell_exec('chmod -x ' . __DIR__ . '/' . $_GET['action'] . '.sh');
    echo $output;
}
