#!/usr/bin/php
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
/*
 * Load configuration files
 */
require_once __DIR__ . '/../config.inc.php';
require_once __DIR__ . '/../aws-php-sdk/sdk.class.php';

class PhpBatchOne {

    private $_vTigerConnect;
    private $_integrationConnect;
    private $_messages = array();
    private $_ses;
    private $_errors = array();

    public function __construct() {
        openlog(
                "phpcronjob1", LOG_PID | LOG_PERROR, LOG_LOCAL0
        );

        /*
         * Trying to connect to vTiger database
         */
        syslog(
                LOG_INFO, "Trying to connect to vTiger database"
        );
        Config::writelog('phpcronjob1', "Trying to connect to vTiger database");

        $this->_vTigerConnect = new mysqli(
                Config::$dbVtiger['db_server'], Config::$dbVtiger['db_username'], Config::$dbVtiger['db_password'], Config::$dbVtiger['db_name'], Config::$dbVtiger['db_port']
        );

        if ($this->_vTigerConnect->connect_errno) {
            throw new Exception('Unable to connect with vTiger DB');
        }

        syslog(
                LOG_INFO, "Connected to vTiger database"
        );
        
        Config::writelog('phpcronjob1', "Connected to vTiger database");
        
        syslog(
                LOG_INFO, "Trying to connect to integration database"
        );
        Config::writelog('phpcronjob1', "Trying to connect to integration database");

        /*
         * Trying to connect to integration database
         */
        $this->_integrationConnect = new mysqli(
                Config::$dbIntegration['db_server'], Config::$dbIntegration['db_username'], Config::$dbIntegration['db_password'], Config::$dbIntegration['db_name'], Config::$dbIntegration['db_port']
        );

        if ($this->_integrationConnect->connect_errno) {
            throw new Exception('Unable to connect with integration DB');
        }
        
        syslog(
                LOG_INFO, "Connected with integration db"
        );
        
        Config::writelog('phpcronjob1', "Connected with integration db");
        
        /*
         * Trying to connect to Amamzon SES
         */
         syslog(
                LOG_INFO, "Trying connecting with Amazon SES"
        );

        Config::writelog('phpcronjob1', "Trying connecting with Amazon SES");

        $this->_ses = new AmazonSES();

        syslog(
                LOG_INFO, "Connected with Amazon SES"
        );
        Config::writelog('phpcronjob1', "Connected with Amazon SES");

    }
    
    /*
     * Get total no of sales order from vtiger db 
     */
    function getSalesOrdersCount() {
      syslog(LOG_INFO, "In getSalesOrdersCount() : Preparing sales order count query");
      
      Config::writelog('phpcronjob1', "In getSalesOrders() : Preparing sales order count query");
      
      $salesOrdersQueryCount = "SELECT SO.salesorderid FROM vtiger_salesorder SO ".
                              "WHERE SO.sostatus IN ('Created','Approved')";
      syslog(
                LOG_INFO, "In getSalesOrdersCount() : Executing Query: " . $salesOrdersQueryCount
        );
        
        Config::writelog('phpcronjob1', "In getSalesOrders() : Executing Query: " . $salesOrdersQueryCount);

       $salesOrdersCount = $this->_vTigerConnect->query($salesOrdersQueryCount);
       
       if (!$salesOrdersCount) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersCount() : Error executing sales order query :" .
                    " ({$this->_vTigerConnect->errno}) - " .
                    "{$this->_vTigerConnect->error}"
            );
                    
            Config::writelog('phpcronjob1', "In getSalesOrders() : Error executing sales order query :" . " ({$this->_vTigerConnect->errno}) - " . "{$this->_vTigerConnect->error}");
            
            throw new Exception(
            "In getSalesOrdersCount() : Error executing sales order query : " .
            "({$this->_vTigerConnect->errno}) - " .
            "{$this->_vTigerConnect->error}"
            );
        }

        if ($salesOrdersCount->num_rows == 0) {
            
            syslog(
                    LOG_WARNING, "In getSalesOrdersCount() : No Sales Order Found!"
            );
            
            Config::writelog('phpcronjob1', "In getSalesOrdersCount() : No Sales Order Found!");
            
            throw new Exception("In getSalesOrdersCount() : No Sales Order Found!");
        }

        return $salesOrdersCount->num_rows;
    }

   /*
    *  Fetch sales order from vtiger db with limit define in config file.
    */
    protected function getSalesOrders() {
        
        syslog(LOG_INFO, "In getSalesOrders() : Preparing sales order query");
        
        Config::writelog('phpcronjob1', "In getSalesOrders() : Preparing sales order query");
        
        $salesOrdersQuery = "SELECT SO.salesorderid, SO.salesorder_no, 
            ACCF." . Config::$customFields['setFiles'] . ", " .
                "ACCF." . Config::$customFields['mosFiles'] . ", " .
                "ACCO.accountname, SO.contactid,
            SO.duedate, SO.sostatus, ACCO.accountid
            FROM vtiger_salesorder SO 
            LEFT JOIN vtiger_account ACCO on ACCO.accountid = SO.accountid
            LEFT JOIN vtiger_accountscf ACCF on ACCF.accountid = ACCO.accountid
            WHERE SO.sostatus IN ('Created','Approved')
            AND (ACCF." . Config::$customFields['setFiles'] .
                " = 'Yes' OR ACCF." . Config::$customFields['mosFiles'] .
                " = 'Yes') LIMIT 0, " . Config::$batchVariable;

        syslog(
                LOG_INFO, "In getSalesOrders() : Executing Query: " . $salesOrdersQuery
        );
        
        Config::writelog('phpcronjob1', "In getSalesOrders() : Executing Query: " . $salesOrdersQuery);

        $salesOrders = $this->_vTigerConnect->query($salesOrdersQuery);

        if (!$salesOrders) {
            
            syslog(
                    LOG_WARNING, "In getSalesOrders() : Error executing sales order query :" .
                    " ({$this->_vTigerConnect->errno}) - " .
                    "{$this->_vTigerConnect->error}"
            );
                    
            Config::writelog('phpcronjob1', "In getSalesOrders() : Error executing sales order query :" . " ({$this->_vTigerConnect->errno}) - " . "{$this->_vTigerConnect->error}");
            
            throw new Exception(
            "In getSalesOrders() : Error executing sales order query : " .
            "({$this->_vTigerConnect->errno}) - " .
            "{$this->_vTigerConnect->error}"
            );
        }

        if ($salesOrders->num_rows == 0) {
            
            syslog(
                    LOG_WARNING, "In getSalesOrders() : No Sales Order Found!"
            );
            
            Config::writelog('phpcronjob1', "In getSalesOrders() : No Sales Order Found!");
            throw new Exception("In getSalesOrders() : No Sales Order Found!");
        }

        return $salesOrders;
    }

   /*
    *  Fetch products by order no from vtiger db 
    */
    protected function getProductsBySalesOrders($salesOrderNo) {
    
        $salesOrderProducts = $this->_vTigerConnect->query(
                "SELECT " .
                "SO.salesorderid, SO.salesorder_no, SO.contactid," .
                "SO.duedate, SO.sostatus, ACCO.accountname, " .
                "ACCO.accountid, PRO.productid, " .
                "PRO.productname, IVP.quantity, " .
                "PCF." . Config::$customFields['basProductId'] . " " .
                "FROM vtiger_salesorder SO " .
                "INNER JOIN vtiger_account ACCO on ACCO.accountid = SO.accountid " .
                "INNER JOIN vtiger_inventoryproductrel IVP on IVP.id = " .
                "SO.salesorderid " .
                "INNER JOIN vtiger_products PRO on PRO.productid = IVP.productid " .
                "INNER JOIN vtiger_productcf PCF " .
                "ON PRO.productid = PCF.productid " .
                "WHERE SO.salesorder_no = '$salesOrderNo'"
        );
        
        syslog(
                LOG_INFO, "Total number of products ($salesOrderNo): " .
                $salesOrderProducts->num_rows
        );
        
        Config::writelog('phpcronjob1', "Total number of products ($salesOrderNo): " . $salesOrderProducts->num_rows);
        
        return $salesOrderProducts;
    }
    
  /*
   * Insert sales order into integration table.
   */
    protected function createIntegrationSalesOrder($salesOrder) {
        
        $batchNo = $salesOrder->salesorder_no . '-' . Config::$batchVariable;

        syslog(
                LOG_INFO, "In createIntegrationSalesOrder() " .
                "Preparing insert sales order query ($salesOrder->salesorder_no)"
        );
        Config::writelog('phpcronjob1', "In createIntegrationSalesOrder() " . "Preparing insert sales order query ($salesOrder->salesorder_no)");
        
        $interfaceQuery = $this->_integrationConnect->query(
                "INSERT INTO sales_orders
            SET `id` = NULL,
            `salesorderid` = $salesOrder->salesorderid,
            `salesorder_no` = '$salesOrder->salesorder_no',
            `contactid` = $salesOrder->contactid,
            `duedate` = '$salesOrder->duedate',
            `accountname` = '$salesOrder->accountname',
            `accountid` = $salesOrder->accountid,
            `batchno` = '$batchNo', 
            `set` = '" . $salesOrder->{Config::$customFields['setFiles']} . "',
            `mos` = '" . $salesOrder->{Config::$customFields['mosFiles']} . "',
            `set_status` = '$salesOrder->sostatus',
            `mos_status` = '$salesOrder->sostatus',
            `created` = now()"
        );
        
        Config::writelog('phpcronjob1', "In createIntegrationSalesOrder() : " . "Inserting sales order: " . $interfaceQuery);
        
        syslog(
                LOG_INFO, "In createIntegrationSalesOrder() : " .
                "Inserting sales order: " . $interfaceQuery
        );

        if (!$interfaceQuery) {
            
            syslog(
                    LOG_WARNING, "Error inserting salesorder $salesOrder->salesorder_no in " .
                    "integration db ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );
            
            Config::writelog('phpcronjob1', "Error inserting salesorder $salesOrder->salesorder_no in " . "integration db ({$this->_integrationConnect->errno}) - " . "$this->_integrationConnect->error");
            
            throw new Exception(
            "Error inserting salesorder $salesOrder->salesorder_no in " .
            "integration db ({$this->_integrationConnect->errno}) - " .
            "$this->_integrationConnect->error"
            );
        }

        return $interfaceQuery;
    }

   /*
    * Insert products into integration table.
    */
    protected function createIntegrationProduct(
    $salesOrderId, $salesOrderProduct
    ) {
       
        syslog(
                LOG_INFO, "In createIntegrationProduct($salesOrderId)" .
                " Preparing insert product query."
        );
       
        Config::writelog('phpcronjob1', 
        "In createIntegrationProduct($salesOrderId)" . " Preparing insert product query.");
       
        $basProductId = Config::$customFields['basProductId'];
        $cf = (string) $salesOrderProduct->$basProductId;
        $interfaceQuery = $this->_integrationConnect->query(
                "INSERT INTO sales_order_products
            SET id = NULL, 
            productname = '$salesOrderProduct->productname',
            productid = $salesOrderProduct->productid,
            productquantity = $salesOrderProduct->quantity,
            featurdate = NULL,
            sales_order_id = $salesOrderId,
            bas_product_id = '$cf',
            created = now()"
        );
       
        Config::writelog('phpcronjob1', "In createIntegrationProduct($salesOrderId) " . "Inserting products ");
       
        syslog(
                LOG_INFO, "In createIntegrationProduct($salesOrderId) " .
                "Inserting products "
        );

        if (!$interfaceQuery) {
            
            syslog(
                    LOG_WARNING, "Error inserting product $salesOrderProduct->productname in " .
                    "integration db ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );
            
            Config::writelog('phpcronjob1', "Error inserting product $salesOrderProduct->productname in " . "integration db ({$this->_integrationConnect->errno}) - " . "{$this->_integrationConnect->error}");
            
            throw new Exception(
            "Error inserting product $salesOrderProduct->productname in " .
            "integration db ({$this->_integrationConnect->errno}) - " .
            "{$this->_integrationConnect->error}"
            );
        }

        return $interfaceQuery;
    }

   /*
    * Update vTiger db with status delivered 
    */
    protected function updateVtigerSalesOrder(
    $salesOrderID, $status = 'Delivered'
    ) {
        
        syslog(
                LOG_INFO, "Updating sales order ($salesOrderID) $status"
        );
        
        Config::writelog('phpcronjob1', "Updating sales order ($salesOrderID) $status");
        
        $updateSaleOrder = $this->_vTigerConnect->query(
                "UPDATE vtiger_salesorder SET " .
                "sostatus = '$status' WHERE salesorderid = " .
                "'$salesOrderID'"
        );

        if (!$updateSaleOrder) {
            
            syslog(
                    LOG_WARNING, "In updateVtigerSalesOrder($salesOrderID, $status) : " .
                    "Error updating salesorder"
            );
            
            Config::writelog('phpcronjob1', "In updateVtigerSalesOrder($salesOrderID, $status) : " . "Error updating salesorder");
            
            throw new Exception(
            "In updateVtigerSalesOrder($salesOrderID, $status) : " .
            "Error updating salesorder"
            );
        }

        return $updateSaleOrder;
    }
    
    /*
     * Send alert mail with errors
     */
    function sendEmailAlert($errorMessage) {
       $messages = "";
       $iCount = 1;
       foreach($errorMessage as $val) {
        $messages .="$iCount: ".$val.PHP_EOL.PHP_EOL;
        $iCount++;
       }
       
       $sesResponseAlert = $this->_ses->send_email(
        "noreply@gizur.com",
        array(
           "ToAddresses" => Config::$toEmailErrorReports
        ),
        array(
            'Subject.Data'=>"Alert! Error arose during sales order processed Cronjon-1",
            'Body.Text.Data'=>"Hi,". PHP_EOL .
            "Below errors arose during sales order processed". PHP_EOL . PHP_EOL .
            $messages .PHP_EOL .
                                PHP_EOL .
                                '--' .
                                PHP_EOL .
                                'Gizur Admin'               
        )       
    );
        
        if ($sesResponseAlert->isOK()) {
            $this->_messages['alertEmail'] =  "Mail sent successfully ";
        } else {
            
            $this->_messages['alertEmail'] =  "Mail Not Sent";
            
            syslog(
                   LOG_INFO, "Some error to sent mail"
                   );
                   
           Config::writelog('phpcronjob1', "Some error to sent mail");

        }
    }
    
    /*
     * Send success alert mail with no of sales order processed
     */
    function sendEmailAlertSuccess($successMessage) {
      
       $sesResponseAlert = $this->_ses->send_email(
        "noreply@gizur.com",
        array(
           "ToAddresses" => Config::$toEmailErrorReports
        ),
        array(
            'Subject.Data'=>"Sales order processed from vtiger Cronjon-1",
            'Body.Text.Data'=>"Hi,". PHP_EOL .
            "Total no of sales order successfully processed from vtiger". PHP_EOL . PHP_EOL .
            "Total: ".$successMessage .PHP_EOL .
                                PHP_EOL .
                                '--' .
                                PHP_EOL .
                                'Gizur Admin'               
        )       
    );
        
        if ($sesResponseAlert->isOK()) {
            $this->_messages['alertEmailSales'] =  "Mail sent successfully ";
        } else {
            $this->_messages['alertEmailSales'] =  "Mail Not Sent";
            syslog(
                   LOG_INFO, "Some error to sent mail"
                   );
                   Config::writelog('phpcronjob1', "Some error to sent mail");

        }
    }

    public function init() {
        try {
            $numberSalesOrders = $this->getSalesOrdersCount();
            syslog(
                    LOG_WARNING, "Total number of order : " .$numberSalesOrders
            );
            Config::writelog('phpcronjob1', "Total number of order : " .$numberSalesOrders);
            $bunchCount = ceil($numberSalesOrders/Config::$batchVariable);
            for($doLoop=1; $doLoop<=$bunchCount; $doLoop++) {
            $salesOrders = $this->getSalesOrders();
             syslog(
                   LOG_INFO, "No of salesOrder: ".$numberSalesOrders
                   );
                   Config::writelog('phpcronjob1', "No of salesOrder: ".$numberSalesOrders);
            /*
             * Update message array with number of sales orders.
             */
            $this->_messages['count'] = $numberSalesOrders;
            $msg = &$this->_messages['salesorders'];

            while ($salesOrder = $salesOrders->fetch_object()) {
                try {
                    /*
                     * Disable auto commit.
                     */
                    syslog(
                            LOG_INFO, "Disabling auto commit"
                    );
                    Config::writelog('phpcronjob1', "Disabling auto commit");
                    $this->_vTigerConnect->autocommit(FALSE);
                    $this->_integrationConnect->autocommit(FALSE);
                    /*
                     * Creating sales order
                     */
                    Config::writelog('phpcronjob1', "Creating sales order: " . json_encode($salesOrder));
                    $this->createIntegrationSalesOrder($salesOrder);

                    $soId = $this->_integrationConnect->insert_id;

                    $salesOrderProducts = $this->getProductsBySalesOrders(
                            $salesOrder->salesorder_no
                    );

                    $msg[$salesOrder->salesorder_no]['count'] = $salesOrderProducts->num_rows;
                    $msgP = &$msg[$salesOrder->salesorder_no]['products'];

                    $flag = true;

                    while ($flag &&
                    $salesOrderProduct = $salesOrderProducts->fetch_object()
                    ) {
                        $msgP[$salesOrderProduct->productname]['qtn'] = $salesOrderProduct->quantity;

                        $flag = $flag && $this->createIntegrationProduct(
                                        $soId, $salesOrderProduct
                        );

                        $msgP[$salesOrderProduct->productname]['status'] = true;
                    }
                    Config::writelog('phpcronjob1', "Updating vtiger sales order status ");
                    if ($flag) {
                        $this->updateVtigerSalesOrder(
                                $salesOrder->salesorderid, 'Delivered'
                        );
                       }
                      
                    $msg[$salesOrder->salesorder_no]['status'] = true;
                    /*
                     * Commit the databases.
                     */
                    $this->_integrationConnect->commit();
                    $this->_vTigerConnect->commit();
                  
                } catch (Exception $e) {
                    $numberSalesOrders--;
                    /*
                     * Store the _messages
                     */
                    $msgP[$salesOrderProduct->productname]['error'] = $e->getMessage();
                    $msgP[$salesOrderProduct->productname]['status'] = false;
                    $this->_errors[] = $e->getMessage();
                    /*
                     * Rollback the connections
                     */
                    $this->_integrationConnect->rollback();
                    $this->_vTigerConnect->rollback();
                }
            }
           }

            $this->_messages['message'] = "$numberSalesOrders number " .
                    "of sales orders processed.";
            $this->sendEmailAlertSuccess($numberSalesOrders);
        } catch (Exception $e) {
            /*
             * Store the message and rollback the connections.
             */
            $this->_messages['message'] = $e->getMessage();
            $this->_errors[] = $e->getMessage();
            /*
             * Rollback the connections
             */
             
            $this->_integrationConnect->rollback();
            $this->_vTigerConnect->rollback();
        }

        syslog(
                LOG_INFO, json_encode($this->_messages)
        );
        Config::writelog('phpcronjob1', "Creating sales order: " . json_encode($this->_messages));
        echo json_encode($this->_messages);
        if(count($this->_errors)>0) {
          //$this->sendEmailAlert($this->_errors);
        }
    }

}

try {
    $phpBatchOne = new PhpBatchOne();
    $phpBatchOne->init();
} catch (Exception $e) {
    syslog(LOG_WARNING, $e->getMessage());
    $this->_errors[] = $e->getMessage();
    //$this->sendEmailAlert($this->_errors);
    echo $e->getMessage();
}
