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
    LOG_INFO, "Try to connect to Integration database"
);
$integrationConnect = new Connect(
    $dbconfigIntegration['db_server'],
    $dbconfigIntegration['db_username'],
    $dbconfigIntegration['db_password'],
    $dbconfigIntegration['db_name']
);

/*
 * Open try to catch exceptions
 */

try {
    /*
     * Try to fetch pending sales orders fron vTiger database 
     */

syslog(
    LOG_INFO, "Connected to Integration database"
);
    $dt = date('Y-m-d');
    $salesOrderIntegration = "SELECT s1.salesorder_no, s1.accountname, ".
    "s1.created, s1.set_status, s2.productname, s2.productquantity ".
    "FROM sales_orders s1, sales_order_products s2 WHERE s1.id = s2.sales_order_id ".
    "AND s1.created LIKE '%".$dt."%'"; 
    
    syslog(LOG_INFO, "Executing Query: " . $salesOrderIntegration);

     $salesOrder = $integrationConnect->query($salesOrderIntegration);

if (!$salesOrder){
        syslog(
            LOG_WARNING, 
            "Error executing integration sales order query : ($integrationConnect->errno) - " .
                "$vTigerConnect->error"
        );
        throw new Exception(
            "Error executing integration sales order query : " . 
            "($integrationConnect->errno) - $integrationConnect->error"
        );
    }
    
    /*
     * If no sales orders found
     * throw exception. 
     */
    if ($salesOrder->num_rows == 0){
        syslog(
            LOG_INFO, 
            "No Sales Order Found!"
        );
        throw new Exception("No Sales Order Found!");        
    }

    
   /*
     * Header of the CSV file content
     */

$SOData =       "Order No;" .
                "Store Name;" .
                "Date & Time;" .
                "Status;" .
                "Product Name;" .
                "Quantity;" .
                "Check Sum\n";

    /*
     * Generate the CSV content
     */    
                
 while ($salesOrders = $salesOrder->fetch_object()) {
       $salesID = preg_replace(
            '/[A-Z]/', '', $salesOrders->salesorder_no
        );
        $originalordernomber = "7777" . $salesID;

        /**
         * If length of order number is 
         * greater then 6 then auto remove 
	 * extra digits from the starting
         */
        $orderlength = strlen($originalordernomber);

        if ($orderlength > 6) {
            $accessorderlength = $orderlength - 6;

            $ordernumber = substr(
                $originalordernomber, $accessorderlength
            );
        }
        else {
          $ordernumber = $originalordernomber;
           }
           $futuredeliveryDate = strtotime(
            date("Y-m-d", strtotime($salesOrders->created)) . "+2 day"
        );
        $futuredeliverydate = date('Y-m-d', $futuredeliveryDate);
           $order = substr($ordernumber,-2);
           $deliveryDate = substr($futuredeliverydate,-2);
           $createdDate = date('Y-m-d',strtotime($salesOrders->created));
           $orderDate =  substr($createdDate,-2);
           $bnr =  substr($salesOrders->productname,-2); 
           //$arr[] = "OrderNo:$order+DeleveryDate:$deliveryDate+OrderDate:$orderDate+BNR:$bnr"; 
           $checkSum = $order+$deliveryDate+$orderDate+$order+$bnr;
                   
       $SOData = $SOData . "$salesOrders->salesorder_no;" .
                "$salesOrders->accountname;" .
                "$salesOrders->created;" .
                "$salesOrders->set_status;" .
                "$salesOrders->productname;" .
                "$salesOrders->productquantity;" .
                "$checkSum\n";
/*fputcsv($output,array($salesOrders->salesorder_no,
                      $salesOrders->accountname,
                      $salesOrders->created,
                      $salesOrders->set_status,
                      $salesOrders->productname,
                      $salesOrders->productquantity,
                      $checkSum));*/
 }
 

$csv_filename = "sales_order"."_".date("Y-m-d").".csv";

     /*
      * Store file in s3 bucket
      */
        $s3 = new AmazonS3();
        $bucket = $amazonSThree['bucket'];
        $file = 'seasonportal/sales-order-reports/'.$csv_filename; 
        $response = $s3->create_object($bucket, $file, array(
            'body' => $SOData,
            'contentType' => 'text/csv'
        ));
         
        if($response->status!=200) {
           throw new Exception("Error to copy file in S3 bucket!");
           syslog(
                   LOG_INFO, "Error to copy file in S3!"
                 );
        } else {
          syslog(
                   LOG_INFO, "file successfully copied in S3!"
                 );
                 $messages['success']="file successfully copied in S3!";

        }        
} catch (Exception $e) {
    /*
     * Store the message and rollbach the connections.
     */
    $messages['message'] = $e->getMessage();
}

/*
 * Close the connections
 */
$integrationConnect->close();

/*
 * Log the message
 */
syslog(LOG_WARNING, json_encode($messages));
echo json_encode($messages);
