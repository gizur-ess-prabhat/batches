#!/usr/bin/php
<?php
/**
 * @category   Cronjobs
 * @package    Reports
 * @subpackage SalesORders
 * @author     Jonas Colmsjö <jonas@gizur.com>
 * @version    SVN: $Id$
 * @link       href="http://gizur.com"
 * @license    Commercial license
 * @copyright  Copyright (c) 2013, Gizur AB, 
 * <a href="http://gizur.com">Gizur AB</a>, All rights reserved.
 *
 * Purpose: Mail report with Sales Ordres
 * Coding standards:
 * http://pear.php.net/manual/en/standards.php
 *
 * PHP version 5.3
 *
 */

/*
 * Load configuration files
 */
require_once __DIR__ . '/../config.inc.php';
require_once __DIR__ . '/../config.database.php';
require_once __DIR__ . '/../../../../../api/protected/vendors/aws-php-sdk/sdk.class.php';

/*
 * Open connection to system logger
 */
openlog(
    "sales_orders_report", LOG_PID | LOG_PERROR, LOG_LOCAL0
);

/*
 * Try to connect to vTiger database as per setting 
 * defined in config files.
 */
syslog(
    LOG_INFO, "Try to connect to vTiger database"
);

$vTigerConnect = new Connect(
    $dbconfigVtiger['db_server'],
    $dbconfigVtiger['db_username'],
    $dbconfigVtiger['db_password'],
    $dbconfigVtiger['db_name']
);

syslog(
    LOG_INFO, "Connected to vTiger database"
);


/*
 * Open try to catch exceptions
 */

try {
    /*
     * Try to fetch pending sales orders fron vTiger database 
     */

    $salesOrdersQuery =  "SELECT 
            a.accountid,
            a.accountname,
            i.productid,
            p.product_no productno,
            p.productname,
            p.productsheet,
            sum(i.quantity) as totalquotes,
            (SELECT 
                SUM(i2.quantity)
             FROM
                vtiger_inventoryproductrel i2
                    INNER JOIN
                vtiger_products p1 ON p1.productid = i2.productid
                    INNER JOIN
                vtiger_crmentity CE ON CE.crmid = i2.id
                    LEFT JOIN
                vtiger_salesorder s2 ON i2.id = s2.salesorderid
             WHERE
                CE.deleted = 0 AND 
                s2.sostatus NOT IN ('Cancelled' , 'Closed') AND 
                p1.productid = p.productid AND 
                s2.accountid = a.accountid
            ) as totalsales
        FROM
            vtiger_inventoryproductrel i
                INNER JOIN
            vtiger_products p ON p.productid = i.productid
                INNER JOIN
            vtiger_crmentity CE2 ON CE2.crmid = i.id
                LEFT JOIN
            vtiger_quotes q ON i.id = q.quoteid
                INNER JOIN
            vtiger_account a ON a.accountid = q.accountid
        WHERE
            CE2.deleted = 0
                AND q.quotestage NOT IN ('Rejected' , 'Delivered', 'Closed')
                AND p.discontinued = 1
        GROUP BY a.accountid , i.productid";

    syslog(LOG_INFO, "Executing Query: " . $salesOrdersQuery);
    
    $salesOrders = $vTigerConnect->query($salesOrdersQuery);

    /*
     * Message array to store error / success messages
     * through out end.
     */
    $messages = array();

    /*
     * In case of unable to fetch sales orders
     * throw exception.
     */
    if (!$salesOrders){
        syslog(
            LOG_WARNING, 
            "Error executing quote order query : ($vTigerConnect->errno) - " .
                "$vTigerConnect->error"
        );
        throw new Exception(
            "Error executing quote order query : " . 
            "($vTigerConnect->errno) - $vTigerConnect->error"
        );
    }

    /*
     * If no pending sales orders found
     * throw exception. 
     */
    if ($salesOrders->num_rows == 0){
        syslog(
            LOG_INFO, 
            "No quotes found!"
        );
        throw new Exception("No quotes found!");        
    }

    /*
     * Update message array with number of sales orders.
     */
    $messages['no_of_records'] = $salesOrders->num_rows;

    /*
     * Iterate through sales orders
     */
    syslog(
        LOG_INFO, 
        "Iterate through fetched rows"
    );

    /*
     * Header of the CSV file content
     */
    $SOData = "Store Name;Product Id;" .
        "Product Name;Description;" .
        "Quote;Sale Order;Left Order\n";

    /*
     * Generate the CSV content
     */    
    while ($salesOrder = $salesOrders->fetch_object()) {
        
        $totalquotes = empty($salesOrder->totalquotes) ? 0 : $salesOrder->totalquotes;
        $totalsales = empty($salesOrder->totalsales) ? 0 : $salesOrder->totalsales;
        $balance = $totalquotes - $totalsales;
        $SOData = $SOData . "$salesOrder->accountname;" .
            "$salesOrder->productno;" .
            "$salesOrder->productname;" .
            "$salesOrder->productsheet;" .
            "$totalquotes;" .
            "$totalsales;" .
            "$balance\n";
    }

    /*
     * Send the Email as attachment
     */
    syslog(
        LOG_INFO, 
        "Send the Email as attachment"
    );     
    $email = new AmazonSES();
    $sesResponse = $email->send_raw_email(
        array(
            'Data' => base64_encode(
                "Subject: Quote and Call-off Report\n".
                "MIME-Version: 1.0\n".
                "Content-type: Multipart/Mixed; boundary=\"NextPart\"\n\n".
                "--NextPart\n".
                "Content-Type: text/plain\n\n".
                "PFA\n" .
                "--NextPart\n" .
                "Content-Type: application/octet-stream; charset=ISO-8859-15; name=\"sales_order_report_" . date('ymd') . ".csv\"\n" .
                "Content-Disposition: attachment; filename=\"quote_and_call-off_report_" . date('ymd') . ".csv\"\n" .
                "Content-Transfer-Encoding: base64\n\n" .
                base64_encode($SOData) .
                "--NextPart"
            )
        ), 
        array(
           "Source" => "noreply@gizur.com",
           "Destinations" => Config::$toEmailReports
        )
    );

    /*
     * Hooray! All done now check if the mail was sent
     */
    
    if ($sesResponse->isOK()) {
       $messages['status'] = "Mail sent";
    } else {
        $messages['status'] = "Mail not sent";
    }

} catch (Exception $e) {
    /*
     * Store the message and rollbach the connections.
     */
    $messages['message'] = $e->getMessage();
    $vTigerConnect->rollback();
}

/*
 * Close the connections
 */
$vTigerConnect->close();

/*
 * Log the message
 */
syslog(LOG_WARNING, json_encode($messages));
echo json_encode($messages);
