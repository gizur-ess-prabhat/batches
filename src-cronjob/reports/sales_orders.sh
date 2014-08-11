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
require_once __DIR__ . '/../aws-php-sdk/sdk.class.php';

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
    'gizurcloud.colm85rhpnd4.eu-west-1.' .
    'rds.amazonaws.com',
    'user_6bd70dc31',
    'fbd70dc30c051',
    'vtiger_7cd70dc3',
    '3306'
);

syslog(
    LOG_INFO, "Try to connect to Integration database"
);
$integrationConnect = new Connect(
    $dbconfigIntegration['db_server'],
    $dbconfigIntegration['db_username'],
    $dbconfigIntegration['db_password'],
    $dbconfigIntegration['db_name']
);


syslog(
    LOG_INFO, "Connected to vTiger database"
);

syslog(
    LOG_INFO, "Connected to Integration database"
);


/*
 * Open try to catch exceptions
 */

try {
    /*
     * Try to fetch pending sales orders fron vTiger database 
     */
     
    $salesOrderIntegrationQuery = "SELECT s1.salesorder_no, s1.accountname,".
    " s1.created, s1.set_status, s2.productname, s2.productquantity"."
    FROM sales_orders s1, sales_order_products s2"."
    WHERE s1.id = s2.sales_order_id";
    
    syslog(LOG_INFO, "Executing Query: " . $salesOrderIntegrationQuery);

     $salesOrdersIntegration = $integrationConnect->query($salesOrderIntegrationQuery);

if (!$salesOrdersIntegration){
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
 while ($salesOrdersIntegrations = $salesOrdersIntegration->fetch_object()) {
       $salesID = preg_replace(
            '/[A-Z]/', '', $salesOrdersIntegrations->salesorder_no
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
            date("Y-m-d", strtotime($salesOrdersIntegrations->created)) . "+2 day"
        );
        $futuredeliverydate = date('ymd', $futuredeliveryDate);
        $createdDate = date('ymd',strtotime($salesOrdersIntegrations->created));

           /// For position 6-7
           $orderOne = substr($ordernumber, 0, 2);
           $deliveryDateOne = substr($futuredeliverydate, 0, 2);  
           $orderDateOne =  substr($createdDate, 0, 2);
           $bnrOne =  substr($salesOrdersIntegrations->productname, 0, 2); 
           $checkSumOne = $orderOne+$deliveryDateOne+$orderDateOne+$orderOne+$bnrOne;
           /// End position 6-7
        
           /// For position 8-9
           $orderTwo = substr($ordernumber, 2, 2);
           $deliveryDateTwo = substr($futuredeliverydate, 2, 2);  
           $orderDateTwo =  substr($createdDate, 2, 2);
           $bnrTwo =  substr($salesOrdersIntegrations->productname, 2, 2); 
           $checkSumTwo = $orderTwo+$deliveryDateTwo+$orderDateTwo+$orderTwo+$bnrTwo;
           /// End position 8-9
        
           /// For position 10-11
           $orderThree = substr($ordernumber,-2);
           $deliveryDateThree = substr($futuredeliverydate,-2);  
           $orderDateThree =  substr($createdDate,-2);
           $bnrThree =  substr($salesOrdersIntegrations->productname,-2); 
           $checkSumThree = $orderThree+$deliveryDateThree+$orderDateThree+$orderThree+$bnrThree;
           /// End position 10-11
         
           $checkSum = $checkSumOne+$checkSumTwo+$checkSumThree;           
           $ord[$salesOrdersIntegrations->salesorder_no] = $checkSum;
           $todayDate = date('ymd');
           if($createdDate==$todayDate) {
           $todayOrder[$ordernumber] = $checkSum; 
           }        
 }


     $salesOrdersQuery =  "SELECT ENT.createdtime, SO.salesorder_no, SO.subject," .
        "SO.duedate, SO.salesorderid, ENT.modifiedtime, ".
        "SO.sostatus, ACCO.accountname, PRO.productname, IVP.quantity " .
        "FROM vtiger_salesorder SO " .
        "INNER JOIN vtiger_crmentity ENT on ENT.crmid = SO.salesorderid " .
        "INNER JOIN vtiger_account ACCO on ACCO.accountid = SO.accountid " .
        "INNER JOIN vtiger_inventoryproductrel IVP on IVP.id=SO.salesorderid " .
        "INNER JOIN vtiger_products PRO on PRO.productid=IVP.productid " .
        "WHERE SO.sostatus<>'Closed' " .
        "AND lower(SO.subject)<>'initial push' AND lower(SO.subject)<>'Intial Push' " .
        "ORDER BY ENT.createdtime, SO.salesorder_no";


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
            "Error executing sales order query : ($vTigerConnect->errno) - " .
                "$vTigerConnect->error"
        );
        throw new Exception(
            "Error executing sales order query : " . 
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
            "No Sales Order Found!"
        );
        throw new Exception("No Sales Order Found!");        
    }

    /*
     * Update message array with number of sales orders.
     */
    $messages['no_sales_orders'] = $salesOrders->num_rows;

    /*
     * Iterate through sales orders
     */
    syslog(
        LOG_INFO, 
        "Iterate through sales orders"
    );

    /*
     * Header of the CSV file content
     */
    $SOData = "Created time;" .
        "Sales Order No;" .
        "Subject;" .
        "SO Status;" .
        "Account Name;" .
        "Product Name;" .
        "Quantity;" .
        "Check Sum\n";
    /*
     * Generate the CSV content
     */
   $flag=0;
    while ($salesOrder = $salesOrders->fetch_object()) {
     if(isset($ord[$salesOrder->salesorder_no])) {
      $chkSum = $ord[$salesOrder->salesorder_no]; 
      } else {
      $chkSum ='';
      }     
        $SOData = $SOData . "$salesOrder->createdtime;" .
                "$salesOrder->salesorder_no;" .
                "$salesOrder->subject;" .
                "$salesOrder->sostatus;" .
                "$salesOrder->accountname;" .
                "$salesOrder->productname;" .
                "$salesOrder->quantity;" .
                "$chkSum\n";
    }
     $orderCount = array_count_values($todayOrder);
     if(isset($orderCount)) {
    foreach($orderCount as $key=>$value) {
         if($value>1) { $flag++; }
      }
     }
      
     $filtered = array_filter($todayOrder, function($values) use ($orderCount) { 
          return $orderCount[$values] > 1;
     });
     asort($filtered);
     $dublicateOrder = "ORDER: CheckSum".PHP_EOL;
     foreach($filtered as $key => $value) {
     $dublicateOrder =  $dublicateOrder.$key.": ".$value.PHP_EOL;
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
                "Subject: Sales order Report\n".
                "MIME-Version: 1.0\n".
                "Content-type: Multipart/Mixed; boundary=\"NextPart\"\n\n".
                "--NextPart\n".
                "Content-Type: text/plain\n\n".
                "PFA\n" .
                "--NextPart\n" .
                "Content-Type: text/plain; charset=ISO-8859-15; name=\"sales_order_report_" . date('ymd') . ".txt\"\n" .
                "Content-Disposition: attachment; filename=\"sales_order_report_" . date('ymd') . ".txt\"\n" .
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
        $messages['status'] =  "Mail Sent";
    } else {
        $messages['status'] =  "Mail Not Sent";
    }
    
     /* Send mail if duplicate checkSum found in a day */
    if($flag>0) {
    syslog(
        LOG_INFO, 
        "Send Alert Mail"
    );
$sesResponseAlert = $email->send_email(
        "noreply@gizur.com",
        array(
           "ToAddresses" => Config::$toEmailReports
        ),
        array(
            'Subject.Data'=>"Alert! Duplicate sales orders found!",
            'Body.Text.Data'=>"Hi,". PHP_EOL .
            "Duplicate Order List..". PHP_EOL . PHP_EOL .
            $dublicateOrder .PHP_EOL .
                                PHP_EOL .
                                '--' .
                                PHP_EOL .
                                'Gizur Admin'               
        )       
    );
    if ($sesResponseAlert->isOK()) {
        $messages['statusAlert'] =  "Mail Sent";
    } else {
        $messages['statusAlert'] =  "Mail Not Sent";
    }
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
