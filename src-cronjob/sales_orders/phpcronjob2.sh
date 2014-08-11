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
 * Load the required files.
 */
require_once __DIR__ . '/../config.inc.php';
require_once __DIR__ . '/../aws-php-sdk/sdk.class.php';

class PhpBatchTwo {

    private $_integrationConnect;
    private $_sqs;
    private $_ses;
    private $_messages = array();
    private $_duplicateFile = array();
    private $_sThree;
    private $_erors = array();

    public function __construct() {
        openlog(
                "phpcronjob2", LOG_PID | LOG_PERROR, LOG_LOCAL0
        );

        /*
         * Trying to connect to integration database
         */      
        syslog(
                LOG_INFO, "Trying to connect to integration database"
        );

        Config::writelog('phpcronjob2', "Trying to connect to integration database");

        /*
         * Trying to connect to integration database
         */
        $this->_integrationConnect = new mysqli(
                Config::$dbIntegration['db_server'], Config::$dbIntegration['db_username'], Config::$dbIntegration['db_password'], Config::$dbIntegration['db_name'], Config::$dbIntegration['db_port']
        );

        if ($this->_integrationConnect->connect_errno)
            throw new Exception('Unable to connect with integration DB');


        syslog(
                LOG_INFO, "Connected with integration db"
        );

        Config::writelog('phpcronjob2', "Connected with integration db");

        /*
         * Trying to connect to Amamzon SQS
         */

        syslog(
                LOG_INFO, "Trying connecting with Amazon SQS"
        );

        Config::writelog('phpcronjob2', "Trying connecting with Amazon SQS");

        $this->_sqs = new AmazonSQS();

        syslog(
                LOG_INFO, "Connected with Amazon SQS"
        );

        Config::writelog('phpcronjob2', "Connected with Amazon SQS");
        
         syslog(
                LOG_INFO, "Trying connecting with Amazon SES"
        );

        Config::writelog('phpcronjob2', "Trying connecting with Amazon SES");

        $this->_ses = new AmazonSES();

        /*
         * Trying to connect to Amamzon SES
         */
        syslog(
                LOG_INFO, "Connected with Amazon SES"
        );

        Config::writelog('phpcronjob2', "Connected with Amazon SES");

        syslog(
                LOG_INFO, "Trying connecting with Amazon _sThree"
        );

        Config::writelog('phpcronjob2', "Trying connecting with Amazon _sThree");

        $this->_sThree = new AmazonS3();

        syslog(
                LOG_INFO, "Connected with Amazon _sThree"
        );

        Config::writelog('phpcronjob2', "Connected with Amazon _sThree");
    }

        /*
         * Fetching total count of sales order with set files
         */    
    function getSalesOrdersCountSet() {
      syslog(LOG_INFO, "In getSalesOrdersCountSet() : Preparing sales order count query");
      Config::writelog('phpcronjob2', "In getSalesOrdersCountSet() : Preparing sales order count query");
      $salesOrdersQueryCount = "SELECT SO.id FROM sales_orders SO ".
                              "WHERE SO.set_status IN ('Created','Approved') AND SO.set = 'Yes'";
      syslog(
                LOG_INFO, "In getSalesOrdersCountSet() : Executing Query: " . $salesOrdersQueryCount
        );
        Config::writelog('phpcronjob2', "In getSalesOrdersCountSet() : Executing Query: " . $salesOrdersQueryCount);

       $salesOrdersCount = $this->_integrationConnect->query($salesOrdersQueryCount);
       if (!$salesOrdersCount) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersCountSet() : Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );
                    
            Config::writelog('phpcronjob2', "In getSalesOrdersCountSet() : Error executing sales order query :" . " ({$this->_integrationConnect->errno}) - " . "{$this->_integrationConnect->error}");
            
            throw new Exception(
            "In getSalesOrdersCount() : Error executing sales order query : " .
            "({$this->_integrationConnect->errno}) - " .
            "{$this->_integrationConnect->error}"
            );
        }

        if ($salesOrdersCount->num_rows == 0) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersCountSet() : No Sales Order Found for SET!"
            );
            Config::writelog('phpcronjob2', "In getSalesOrdersCountSet() : No Sales Order Found for SET!");
            throw new Exception("In getSalesOrdersCountSet() : No Sales Order Found for SET!");
        }

        return $salesOrdersCount->num_rows;
    }
    
    /*
     * Fetching total count of sales order with mos files
     */ 
    function getSalesOrdersCountMos() {
      syslog(LOG_INFO, "In getSalesOrdersCountMos() : Preparing sales order count query");
      Config::writelog('phpcronjob2', "In getSalesOrdersCountMos() : Preparing sales order count query");
      $salesOrdersQueryCount = "SELECT DISTINCT SO.accountname FROM sales_orders SO
            WHERE SO.mos_status IN ('Created','Approved') AND SO.mos = 'Yes'";
      syslog(
                LOG_INFO, "In getSalesOrdersCountMos() : Executing Query: " . $salesOrdersQueryCount
        );
        Config::writelog('phpcronjob2', "In getSalesOrdersCountMos() : Executing Query: " . $salesOrdersQueryCount);

       $salesOrdersCount = $this->_integrationConnect->query($salesOrdersQueryCount);
       if (!$salesOrdersCount) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersCountMos() : Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );
                    
            Config::writelog('phpcronjob2', "In getSalesOrdersCountMos() : Error executing sales order query :" . " ({$this->_integrationConnect->errno}) - " . "{$this->_integrationConnect->error}");
            
            throw new Exception(
            "In getSalesOrdersCountMos() : Error executing sales order query : " .
            "({$this->_integrationConnect->errno}) - " .
            "{$this->_integrationConnect->error}"
            );
        }
        if ($salesOrdersCount->num_rows == 0) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersCountMos() : No Sales Order Found for MOS!"
            );
            Config::writelog('phpcronjob2', "In getSalesOrdersCountMos() : No Sales Order Found for MOS!");
            throw new Exception("In getSalesOrdersCountMos() : No Sales Order Found for MOS!");
        }

        return $salesOrdersCount->num_rows;
    }

    /*
     * Fetching no of sales order with set files
     */ 
    protected function getSalesOrdersForSet() {
        syslog(
                LOG_INFO, "In getSalesOrdersForSet() : Preparing sales order query"
        );

        Config::writelog('phpcronjob2', "In getSalesOrdersForSet() : Preparing sales order query");

        $salesOrdersQuery = "SELECT * FROM sales_orders SO 
            WHERE SO.set_status IN ('Created','Approved') AND SO.set = 'Yes'
            LIMIT 0, " . Config::$batchVariable;

        syslog(
                LOG_INFO, "In getSalesOrdersForSet() : Executing Query: " . $salesOrdersQuery
        );

        Config::writelog('phpcronjob2', "In getSalesOrdersForSet() : Executing Query: " . $salesOrdersQuery);

        $salesOrders = $this->_integrationConnect->query($salesOrdersQuery);

        if (!$salesOrders) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersForSet() : " .
                    "Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );

            Config::writelog(LOG_WARNING, "In getSalesOrdersForSet() : " .
                    "Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}");

            throw new Exception(
            "In getSalesOrdersForSet() : Error " .
            "executing sales order query : " .
            "({$this->_integrationConnect->errno}) - " .
            "{$this->_integrationConnect->error}"
            );
        }

        if ($salesOrders->num_rows == 0) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersForSet() : No Sales Order Found!"
            );

            Config::writelog(LOG_WARNING, "In getSalesOrdersForSet() : No Sales Order Found!");

            throw new Exception(
            "In getSalesOrdersForSet() : No Sales Order Found!"
            );
        }

        return $salesOrders;
    }


    /*
     * Fetching no of sales order with set files
     */ 
    protected function getSalesOrdersForXml($accountName) {
        syslog(
                LOG_INFO, "In getSalesOrdersForXml() : Preparing sales order query"
        );

        Config::writelog('phpcronjob2', "getSalesOrdersForXml() : Preparing sales order query");

        $salesOrdersQuery = "SELECT * FROM sales_orders SO 
            WHERE SO.mos_status IN ('Created','Approved') AND SO.mos = 'Yes'
            AND SO.accountname = '$accountName' ";

        syslog(
                LOG_INFO, "In getSalesOrdersForXml() : Executing Query: " . $salesOrdersQuery
        );

        Config::writelog('phpcronjob2', "In getSalesOrdersForXml() : Executing Query: " . $salesOrdersQuery);

        $salesOrders = $this->_integrationConnect->query($salesOrdersQuery);

        if (!$salesOrders) {
            syslog(
                    LOG_WARNING, "getSalesOrdersForXml() : " .
                    "Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );

            Config::writelog(LOG_WARNING, "getSalesOrdersForXml() : " .
                    "Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}");

            throw new Exception(
            "In getSalesOrdersForXml() : Error " .
            "executing sales order query : " .
            "({$this->_integrationConnect->errno}) - " .
            "{$this->_integrationConnect->error}"
            );
        }

        if ($salesOrders->num_rows == 0) {
            syslog(
                    LOG_WARNING, "In getSalesOrdersForXml() : No Sales Order Found! for account".$orderId
            );

            Config::writelog(LOG_WARNING, "In getSalesOrdersForXml() : No Sales Order Found!");

            throw new Exception(
            "In getSalesOrdersForXml() : No Sales Order Found!"
            );
        }

        return $salesOrders;
    }



    /*
     * Fetching no of sales order with mos files
     */ 
    protected function getAccountsForMos() {
        syslog(
                LOG_INFO, "In getAccountsForMos() : Preparing sales order query"
        );
        Config::writelog('phpcronjob2', "In getAccountsForMos() : Preparing sales order query");

        $salesOrdersQuery = "SELECT DISTINCT SO.accountname FROM sales_orders SO
            WHERE SO.mos_status IN ('Created','Approved') AND SO.mos = 'Yes'
            LIMIT 0, " . Config::$batchVariable;

        syslog(
                LOG_INFO, "In getAccountsForMos() : Executing Query: " . $salesOrdersQuery
        );
        Config::writelog('phpcronjob2', "In getAccountsForMos() : Executing Query: " . $salesOrdersQuery);

        $salesOrders = $this->_integrationConnect->query($salesOrdersQuery);

        if (!$salesOrders) {
            syslog(
                    LOG_WARNING, "In getAccountsForMos() : Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}"
            );

            Config::writelog(LOG_WARNING, "In getAccountsForMos() : Error executing sales order query :" .
                    " ({$this->_integrationConnect->errno}) - " .
                    "{$this->_integrationConnect->error}");

            throw new Exception(
            "In getAccountsForMos() : " .
            "Error executing sales order query : " .
            "({$this->_integrationConnect->errno}) - " .
            "{$this->_integrationConnect->error}"
            );
        }

        if ($salesOrders->num_rows == 0) {
            syslog(
                    LOG_WARNING, "In getAccountsForMos() : No Sales Order Found!"
            );

            Config::writelog(LOG_WARNING, "In getAccountsForMos() : No Sales Order Found!");

            throw new Exception(
            "In getAccountsForMos() : No Sales Order Found!"
            );
        }

        return $salesOrders;
    }
    
    /*
     * Fetching products details by sales order id
     */ 
    protected function getProductsBySalesOrderId($salesOrderId) {
        syslog(
                LOG_INFO, "In getProductsBySalesOrderId($salesOrderId) : Fetching products"
        );

        Config::writelog('phpcronjob2', "In getProductsBySalesOrderId($salesOrderId) : Fetching products");
        /*
         * Fetch current sales order products.
         */
        $salesOrderProducts = $this->_integrationConnect->query(
                "SELECT *" .
                "FROM sales_order_products SO " .
                "WHERE SO.sales_order_id = '$salesOrderId'"
        );

        syslog(
                LOG_INFO, "Total number of products ($salesOrderId): " .
                $salesOrderProducts->num_rows
        );

        Config::writelog('phpcronjob2', "Total number of products ($salesOrderId): " .
                $salesOrderProducts->num_rows);


        return $salesOrderProducts;
    }

    
    /*
     * Fetching products details by account name
     */ 
    protected function getProductsByAccountName($accountname) {
        syslog(
                LOG_INFO, "In getProductsByAccountName($accountname) : Fetching products"
        );

        Config::writelog('phpcronjob2', "In getProductsByAccountName($accountname) : Fetching products");
        /*
         * Fetch current sales order products.
         */
        $query = "SELECT * " .
                "FROM sales_order_products SOP LEFT JOIN sales_orders SO ON " .
                "SO.id = SOP.sales_order_id " .
                "WHERE SO.accountname = '$accountname'";

        syslog(
                LOG_INFO, "Fetching products ($accountname): $query"
        );

        Config::writelog('phpcronjob2', "Fetching products ($accountname): $query");

        $products = $this->_integrationConnect->query($query);

        syslog(
                LOG_INFO, "Total number of products ($accountname): " .
                $products->num_rows
        );
        Config::writelog('phpcronjob2', "Total number of products ($accountname): " .
                $products->num_rows);

        return $products;
    }

    
    /*
     * update integration sales order with status delivered
     */ 
    protected function updateIntegrationSalesOrder(
    $salesOrderID, $column, $status = 'Delivered'
    ) {
        syslog(
                LOG_INFO, "In updateIntegrationSalesOrder($salesOrderID, $status) : " .
                "Updating sales order ($salesOrderID) column $column to $status"
        );

        Config::writelog('phpcronjob2', "In updateIntegrationSalesOrder($salesOrderID, $status) : " .
                "Updating sales order ($salesOrderID) column $column to $status");

        $updateSaleOrder = $this->_integrationConnect->query(
                "UPDATE sales_orders SET " .
                "$column = '$status' WHERE id = " .
                "'$salesOrderID' LIMIT 1"
        );

        if (!$updateSaleOrder) {
            syslog(
                    LOG_WARNING, "In updateIntegrationSalesOrder($salesOrderID, $status) : " .
                    "Error updating sales order"
            );

            Config::writelog(LOG_WARNING, "In updateIntegrationSalesOrder($salesOrderID, $status) : " .
                    "Error updating sales order");

            throw new Exception(
            "In updateIntegrationSalesOrder($salesOrderID, $status) : " .
            "Error updating sales order"
            );
        }

        return $updateSaleOrder;
    }

    
    /*
     *  Update integration sales order by account with status delivered
     */ 
    protected function updateIntegrationSalesOrderByAccountName(
    $accountname, $column, $status = 'Delivered'
    ) {
        syslog(
                LOG_INFO, "In updateIntegrationSalesOrderByAccountName(" .
                "$accountname, $column, $status) : " .
                "Updating store ($accountname) column $column to $status"
        );

        Config::writelog('phpcronjob2', "In updateIntegrationSalesOrderByAccountName(" .
                "$accountname, $column, $status) : " .
                "Updating store ($accountname) column $column to $status");

        $updateSaleOrder = $this->_integrationConnect->query(
                "UPDATE sales_orders SO SET " .
                "SO.$column = '$status' WHERE SO.accountname = " .
                "'$accountname'"
        );

        if (!$updateSaleOrder) {
            syslog(
                    LOG_WARNING, "In updateIntegrationSalesOrderByAccountName(" .
                    " $accountname, $column, $status) : " .
                    "Error updating sales orders"
            );

            Config::writelog(LOG_WARNING, "In updateIntegrationSalesOrderByAccountName(" .
                    " $accountname, $column, $status) : " .
                    "Error updating sales orders");

            throw new Exception(
            "In updateIntegrationSalesOrderByAccountName(" .
            " $accountname, $column, $status) : " .
            "Error updating sales orders"
            );
        }

        return $updateSaleOrder;
    }

    
    /*
     * Creating Set Files
     */ 
    protected function createSETFile($salesOrder, &$msg) {
        $cnt = 0;

        $soProducts = $this->getProductsBySalesOrderId(
                $salesOrder->id
        );

        $msg[$salesOrder->salesorder_no]['count'] = $soProducts->num_rows;

        if (empty($this->_duplicateFile[$salesOrder->accountname]))
            $createdDate = date("YmdHi");
        else {
            $cnt = count($this->_duplicateFile[$salesOrder->accountname]);
            $createdDate = date("YmdHi", strtotime("+$cnt minutes"));
        }

        $this->_duplicateFile[$salesOrder->accountname][] = $createdDate;

        /*
         * Generate the file name.
         */
        $fileName = "SET.GZ.FTP.IN.BST.$createdDate." .
                "$salesOrder->accountname";

        $msg[$salesOrder->salesorder_no]['file'] = $fileName;
        /*
         * Initialize variables used in creating SET file contents.
         */
        $leadzero = "";
        $productnamearray = array();
        $multiproduct = array();
        $productlength = "";
        $leadzeroproduct = "";
        $productquantitylength = "";
        $leadzeroproductquantity = "";

        while ($sOWProduct = $soProducts->fetch_object()) {

            /**
             * Check duplicate products and 
             * write product name in the set file separating with +
             */
            if (!in_array($sOWProduct->productname, $productnamearray)) {
                $productlength = strlen($sOWProduct->productname);
                $productquantitylength = strlen(
                        $sOWProduct->productquantity
                );

                if ($productlength < 6) {
                    $leadzeroproduct = Functions::leadingzero(
                                    6, $productlength
                    );
                }

                if ($productquantitylength < 3) {
                    $leadzeroproductquantity = Functions::leadingzero(
                                    3, $productquantitylength
                    );
                }

                $multiproduct[] = "189" . $leadzeroproduct .
                        $sOWProduct->productname .
                        $leadzeroproductquantity .
                        $sOWProduct->productquantity;

                $productnamearray[] = $sOWProduct->productname;
            }
        }

        $accountlenth = strlen($salesOrder->accountname);
        if ($accountlenth < 6) {
            $leadzero = Functions::leadingzero(6, $accountlenth);
        }
        $finalformataccountname = $leadzero .
                $salesOrder->accountname;

        $salesID = preg_replace(
                '/[A-Z]/', '', $salesOrder->salesorder_no
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
        } else
            $ordernumber = $originalordernomber;

        if (!empty($salesOrder->duedate) && $salesOrder->duedate != '0000-00-00')
            $deliveryday = date(
                    "ymd", strtotime($salesOrder->duedate)
            );
        else
            $deliveryday = date('ymd');

        $futuredeliveryDate = strtotime(
                date("Y-m-d", strtotime($deliveryday)) . "+2 day"
        );
        $futuredeliverydate = date('ymd', $futuredeliveryDate);

        $currentdate = date("YmdHi");
        $finalformatproductname = implode("+", $multiproduct);
        unset($multiproduct);
        unset($productnamearray);

        $milliSec = Functions::getMilliSecond();
        /*
         * Generate the file content
         */
        $contentF = "HEADERGIZUR           " . $currentdate .
                "{$milliSec}M256      RUTIN   .130KF27777100   " .
                "mottagning initierad                               " .
                "                                          001" .
                $finalformataccountname . "1+03751+038" . $ordernumber .
                "+226" . $futuredeliverydate . "+039" .
                $deliveryday . "+040" . $ordernumber . "+" .
                $finalformatproductname . "+C         RUTIN   " .
                ".130KF27777100   Mottagning avslutad    " .
                "BYTES/BLOCKS/RETRIES=1084 /5    /0.";

        syslog(
                LOG_INFO, "File $fileName content generated"
        );
        Config::writelog('phpcronjob2', "File $fileName content generated");
        /*
         * Add next line character at every 80 length
         */
        syslog(
                LOG_INFO, "Adding next line char $fileName at every 80 chars"
        );

        Config::writelog('phpcronjob2', "Adding next line char $fileName at every 80 chars");

        $pieces = str_split($contentF, 80);
        $contentF = join(Config::$lineBreak, $pieces);

        syslog(
                LOG_INFO, "File $fileName contents: " . $contentF
        );

        Config::writelog('phpcronjob2', "File $fileName contents: " . $contentF);

        $messageQ = array();

        $messageQ['file'] = $fileName;
        $messageQ['content'] = $contentF;
        $messageQ['type'] = 'SET';

        return $messageQ;
    }
    
    
    protected function createXMLFile($accounts, &$msg) {
$cnt = 0;

// Define xml header

       $dom = new DOMDocument("1.0","utf-8");
        header("Content-Type: text/plain");

        $main = $dom->createElement("order:orderMessage");
        $dom->appendChild($main);

        $orderAttr  = $dom->createAttribute("xmlns:order");
        $main->appendChild($orderAttr);

        $orderAttrText = $dom->createTextNode('urn:gs1:ecom:order:xsd:3');
        $orderAttr->appendChild($orderAttrText);

        $shAttr  = $dom->createAttribute("xmlns:sh");
        $main->appendChild($shAttr);

        $shAttrText = $dom->createTextNode('http://www.unece.org/cefact/namespaces/StandardBusinessDocumentHeader');
        $shAttr->appendChild($shAttrText);

        $xsiAttr  = $dom->createAttribute("xmlns:xsi");
        $main->appendChild($xsiAttr);

        $xsiAttrText = $dom->createTextNode('http://www.w3.org/2001/XMLSchema-instance');
        $xsiAttr->appendChild($xsiAttrText);

        $schemaLocationAttr  = $dom->createAttribute("xsi:schemaLocation");
        $main->appendChild($schemaLocationAttr);

        $schemaLocationText = $dom->createTextNode('urn:gs1:ecom:order:xsd:3 ../Schemas/gs1/ecom/Order.xsd');
        $schemaLocationAttr->appendChild($schemaLocationText);


        /*
         * Generate the file name.
         */
         $accountName = $accounts->accountname;
        $createdDate = date("YmdHi");
        $fileName = "XML.GZ.FTP.IN.BST.$createdDate." .
                "$accountName";

        $msg[$accountName]['file'] = $fileName;


$soOrders = $this->getSalesOrdersForXml(
            $accountName  
        );
        
         while ($salesOrder = $soOrders->fetch_object()) {


        $soProducts = $this->getProductsBySalesOrderId(
                $salesOrder->id
        );

        $msg[$salesOrder->salesorder_no]['count'] = $soProducts->num_rows;

     
        /*
         * Initialize variables used in creating SET file contents.
         */
        $leadzero = "";
        $productnamearray = array();
        $multiproduct = array();
        $productlength = "";
        $leadzeroproduct = "";
        $productquantitylength = "";
        $leadzeroproductquantity = "";

        $accountlenth = strlen($accountName);
        if ($accountlenth < 6) {
            $leadzero = Functions::leadingzero(6, $accountlenth);
        }
        $finalformataccountname = $leadzero .
                $accountName;

        $salesID = preg_replace(
                '/[A-Z]/', '', $salesOrder->salesorder_no
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
        } else
            $ordernumber = $originalordernomber;

        if (!empty($salesOrder->duedate) && $salesOrder->duedate != '0000-00-00')
            $deliveryday = date(
                    "ymd", strtotime($salesOrder->duedate)
            );
        else
            $deliveryday = date('ymd');

        $futuredeliveryDate = strtotime(
                date("Y-m-d", strtotime($deliveryday)) . "+2 day"
        );
        $futuredeliverydate = date('Y-m-d', $futuredeliveryDate);
        $dateNo = new DateTime($futuredeliverydate);
        $weekNo = $dateNo->format("W");
        $futuredeliverydateY = date('Y',strtotime($futuredeliverydate)); 


        $currentdate = date("YmdHi");
        $milliSec = Functions::getMilliSecond();
        /*
         * Generate the xml file content
         */
        $date = new DateTime($futuredeliverydate);
        $week = $date->format("W");
        $creationDateTimeData = date('c');
        $glnData = $finalformataccountname;
        $entityIdentificationData = $ordernumber;
        $orderTypeCodeData = '220';
        $requestedDeliveryDateTimeData = $futuredeliverydate;
        $additionalOrderInstructionData = $futuredeliverydateY.''.$weekNo;
        $lineItemNumberText = 1;
        $materialSpecificationData = '';
        
        // Creating XML file using php dom document.
        
        $root = $dom->createElement("order");
        $main->appendChild($root);

        $creationDateTime = $dom->createElement("creationDateTime");
        $root->appendChild($creationDateTime);

        $creationDateTimeText = $dom->createTextNode($creationDateTimeData);
        $creationDateTime->appendChild($creationDateTimeText);

        $orderIdentification = $dom->createElement("orderIdentification");
        $root->appendChild($orderIdentification);

        $entityIdentification = $dom->createElement("entityIdentification");
        $orderIdentification->appendChild($entityIdentification);

        $entityIdentificationText = $dom->createTextNode($entityIdentificationData);
        $entityIdentification->appendChild($entityIdentificationText);

        $orderTypeCode = $dom->createElement("orderTypeCode");
        $root->appendChild($orderTypeCode);

        $orderTypeCodeText = $dom->createTextNode($orderTypeCodeData);
        $orderTypeCode->appendChild($orderTypeCodeText);

        $buyer = $dom->createElement("buyer");
        $root->appendChild($buyer);

        $gln = $dom->createElement("gln");
        $buyer->appendChild($gln);

        $glnText = $dom->createTextNode($glnData);
        $gln->appendChild($glnText);

        $orderLogisticalInformation = $dom->createElement("orderLogisticalInformation");
        $root->appendChild($orderLogisticalInformation);

        $orderLogisticalDateInformation = $dom->createElement("orderLogisticalDateInformation");
        $orderLogisticalInformation->appendChild($orderLogisticalDateInformation);

        $requestedDeliveryDateTime  = $dom->createElement("requestedDeliveryDateTime");
        $orderLogisticalDateInformation->appendChild($requestedDeliveryDateTime);

        $requestedDeliveryDateTimeText = $dom->createTextNode($requestedDeliveryDateTimeData);
        $requestedDeliveryDateTime->appendChild($requestedDeliveryDateTimeText);

        $additionalOrderInstruction  = $dom->createElement("additionalOrderInstruction");
        $root->appendChild($additionalOrderInstruction);

        $additionalOrderInstructionText = $dom->createTextNode($additionalOrderInstructionData);
        $additionalOrderInstruction->appendChild($additionalOrderInstructionText);


                while ($sOWProduct = $soProducts->fetch_object()) {

                    /**
                     * Check duplicate products and 
                     * 
                     */
                    if (!in_array($sOWProduct->productname, $productnamearray)) {
                        $productlength = strlen($sOWProduct->productname);
                        $productquantitylength = strlen(
                                $sOWProduct->productquantity
                        );

                        if ($productlength < 6) {
                            $leadzeroproduct = Functions::leadingzero(
                                            6, $productlength
                            );
                        }

                        if ($productquantitylength < 3) {
                            $leadzeroproductquantity = Functions::leadingzero(
                                            3, $productquantitylength
                            );
                        }

                      $productName =  $leadzeroproduct .
                                $sOWProduct->productname;
                                
                       $productQty =  $leadzeroproductquantity .
                                $sOWProduct->productquantity;        

                        
                    }
                      $productnamearray[] = $sOWProduct->productname;
                
        $orderLineItem  = $dom->createElement("orderLineItem");
        $root->appendChild($orderLineItem);

        $lineItemNumber  = $dom->createElement("lineItemNumber");
        $orderLineItem->appendChild($lineItemNumber);

        $lineItemNumberText = $dom->createTextNode($lineItemNumberText);
        $lineItemNumber->appendChild($lineItemNumberText);

        $transactionalTradeItem  = $dom->createElement("transactionalTradeItem");
        $orderLineItem->appendChild($transactionalTradeItem);

        $gtin  = $dom->createElement("gtin");
        $transactionalTradeItem->appendChild($gtin);

        $gtinText = $dom->createTextNode($productName);
        $gtin->appendChild($gtinText);

        $materialSpecification  = $dom->createElement("materialSpecification");
        $orderLineItem->appendChild($materialSpecification);

        $materialSpecificationText = $dom->createTextNode($sOWProduct->bas_product_id);
        $materialSpecification->appendChild($materialSpecificationText);

        $requestedQuantity  = $dom->createElement("requestedQuantity");
        $orderLineItem->appendChild($requestedQuantity);

        $requestedQuantityText = $dom->createTextNode($productQty);
        $requestedQuantity->appendChild($requestedQuantityText);

        $requestedQuantityAttr  = $dom->createAttribute("measurementUnitCode");
        $requestedQuantity->appendChild($requestedQuantityAttr);

        $requestedQuantityAttrText = $dom->createTextNode('CAR');
        $requestedQuantityAttr->appendChild($requestedQuantityAttrText); 
        }
         unset($productnamearray);
      }
       
               $contentF = $dom->saveXML();
                $messageQ = array();

                $messageQ['file'] = $fileName;
                $messageQ['content'] = $contentF;
                $messageQ['type'] = 'XML';
                return $messageQ;
    }

    /*
     * Creating MOS Files
     */ 
    protected function createMOSFile($account, &$msg) {
        $soProducts = $this->getProductsByAccountName(
                $account->accountname
        );

        $msg[$account->accountname]['count'] = $soProducts->num_rows;

        $createdDate = date("YmdHi");
        $dt = date("Ymd");
        /*
         * Generate the file name.
         */
        $fileName = "MOS.GZ.FTP.IN.BST.$createdDate." .
                "$account->accountname";
        $msg[$account->accountname]['file'] = $fileName;

        $sequence = 1;

        $seqZero = Functions::leadingzero(5, strlen((string) $sequence));
        $cntZero = Functions::leadingzero(
                        5, strlen((string) $soProducts->num_rows)
        );

        $header = "{$seqZero}{$sequence}0000" .
                "{$cntZero}{$soProducts->num_rows}{$dt}1727130700518" .
                "000000000000000000000000000000000000000000000" . Config::$lineBreak;
        $contentF = $header;

        $sequence++;

        while ($sOWProduct = $soProducts->fetch_object()) {
            $seqZero = Functions::leadingzero(5, strlen((string) $sequence));

            if (!empty($sOWProduct->duedate) &&
                    $sOWProduct->duedate != '0000-00-00')
                $deliveryday = date(
                        "ymd", strtotime($sOWProduct->duedate)
                );
            else
                $deliveryday = date('ymd');

            $week = date('yW', strtotime($deliveryday));

            $campaignWeek = date(
                    'yW', strtotime($deliveryday . "+1 week")
            );

            $basProId = explode('-', $sOWProduct->bas_product_id);

            $dummyOne = (string) '3095';
            $vgr = (string) $basProId[0];
            $art = (string) $basProId[1];
            $varubet = (string) '0000';
            $store = (string) $sOWProduct->accountname;

            $quantity = (string) $sOWProduct->productquantity;
            $qtnZero = Functions::leadingzero(7, strlen((string) $quantity));

            $dummyTwo = (string) '1000';

            $reservationId = (string) '0000000';

            $contentF .= "{$seqZero}{$sequence}{$dummyOne}" .
                    "{$vgr}{$art}{$varubet}{$store}" .
                    "{$week}{$qtnZero}{$quantity}" .
                    "{$dummyTwo}{$campaignWeek}{$reservationId}" .
                    Config::$lineBreak;
            $sequence++;
        }

        $seqZero = Functions::leadingzero(5, strlen((string) $sequence));
        $cntZero = Functions::leadingzero(
                        5, strlen((string) $soProducts->num_rows)
        );

        $footer = "{$seqZero}{$sequence}9999" .
                "{$cntZero}{$soProducts->num_rows}{$dt}1727130700518" .
                "000000000000000000000000000000000000000000000";
        $contentF .= $footer;

        syslog(
                LOG_INFO, "File $fileName contents: " . $contentF
        );

        Config::writelog('phpcronjob2', "File $fileName contents: " . $contentF);

        $messageQ = array();

        $messageQ['file'] = $fileName;
        $messageQ['content'] = $contentF;
        $messageQ['type'] = 'MOS';

        return $messageQ;
    }
 
    /*
     * Store file SET/MOS files in S3 bucket
     */    
    protected function storeFileInSThree(
    $bucket, $fileFolder, $fileName, $contentF
    ) {
        /*
         * Store file in S3 Bucket
         */
        syslog(
                LOG_INFO, "Store file in S3 Bucket"
        );

        Config::writelog('phpcronjob2', "Store file in S3 Bucket");

        $responseSThree = $this->_sThree->create_object(
                $bucket, $fileFolder . $fileName, array(
            'body' => $contentF,
            'contentType' => 'plain/text',
            'headers' => array(
                'Cache-Control' => 'max-age',
                'Content-Language' => 'en-US',
                'Expires' =>
                'Thu, 01 Dec 1994 16:00:00 GMT',
            ))
        );

        if (!$responseSThree->isOK()) {
            throw new Exception(
            "Unable to save file $fileName in S3 bucket " .
            "($bucket)"
            );

            syslog(
                    LOG_WARNING, "Unable to save file $fileName in S3 bucket " .
                    "($bucket) Respone json".json_encode($responseSThree)
            );
            Config::writelog(LOG_WARNING, "Unable to save file $fileName in S3 bucket " .
                    "($bucket) Respone json".json_encode($responseSThree));
        }
        return $responseSThree;
    }

    /*
     * Store file in Amamzon S3
     */    
    protected function storeFileInMessageQ($qUrl, $messageQ) {
        /*
         * Store file name and file content to message queue.
         */
        syslog(
                LOG_INFO, "Store file name and file content to message queue."
        );

        Config::writelog('phpcronjob2', "Store file name and file content to message queue.");

        $responseQ = $this->_sqs->send_message(
                $qUrl, $messageQ
        );

        /*
         * If unable to store file content at queue,
         * raise the exception
         */
        if ($responseQ->status !== 200) {
            syslog(
                    LOG_WARNING, "Error in sending file to message queue.".json_encode($responseQ)
            );

            Config::writelog(LOG_WARNING, "Error in sending file to message queue.".json_encode($responseQ));

            throw new Exception("Error in sending file to message queue.".json_encode($responseQ));
        }

        return $responseQ;
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
            'Subject.Data'=>"Alert! Error arose during sales order processed Cronjon-2",
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
                   Config::writelog('phpcronjob2', "Some error to sent mail");

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
            'Subject.Data'=>"Sales order processed from integration: Cronjob-2",
            'Body.Text.Data'=>"Hi,". PHP_EOL .
            "Total no of messages pushed in SQS successfully". PHP_EOL . PHP_EOL .
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
        /*
         * Process SET Files
         */
        try {
            $numberSalesOrders = $this->getSalesOrdersCountSet(); 
            $bunchCount = ceil($numberSalesOrders/Config::$batchVariable);
            for($doLoop=1; $doLoop<=$bunchCount; $doLoop++) {
            
            $salesOrders = $this->getSalesOrdersForSet();
            /*
             * Update message array with number of sales orders.
             */
            $this->_messages['set']['count'] = $numberSalesOrders;
            $msg = &$this->_messages['set']['salesorders'];

            while ($salesOrder = $salesOrders->fetch_object()) {
                try {
                    /*
                     * Disable auto commit.
                     */
                    syslog(
                            LOG_INFO, "Disabling auto commit"
                    );

                    Config::writelog('phpcronjob2', "Disabling auto commit");

                    $this->_integrationConnect->autocommit(FALSE);

                    $msg[$salesOrder->salesorder_no]['status'] = false;

                    $setFile = $this->createSETFile($salesOrder, $msg);
                    
                    if (isset($setFile) && !empty($setFile)) {
                        $this->storeFileInSThree(
                                Config::$amazonSThree['setBucket'], Config::$amazonSThree['setFolder'], $setFile['file'], $setFile['content']
                        );
                    
                        Config::writelog('phpcronjob2', "SET files generated and placed in S3 bucket successfully");
                        
                    } else {
                          
                        throw new Exception('No SET file has been created, Check cronjob2 at line number:687');  
                    }
                    
                    if (isset($setFile) && !empty($setFile)) {
                    $this->storeFileInMessageQ(
                            Config::$amazonQ['url'], json_encode($setFile)
                    );
                                       
                        Config::writelog('phpcronjob2', "SET files generated successfully and placed SQS");
                        
                    } else {
                          
                        throw new Exception('SET files could not be sent to SQS, Check cronjob2 at line number:702');  
                    }
                    
                    $msg[$salesOrder->salesorder_no]['status'] = true;
                    $fileName = $setFile['file'];

                    $this->updateIntegrationSalesOrder(
                            $salesOrder->id, 'set_status', 'Delivered'
                    );
                    /*
                     * Commit the databases.
                     */
                    $this->_integrationConnect->commit();
                } catch (Exception $e) {
                    $numberSalesOrders--;
                    $this->_messages['message'] = $e->getMessage();
                    $this->_errors[] = $e->getMessage();
                    /*
                     * Rollback the connections
                     */
                    $this->_integrationConnect->rollback();
                }
            }
          }
            $this->_messages['set']['message'] = "$numberSalesOrders number " .
                    "of sales orders processed for SET files.";
        } catch (Exception $e) {
            $this->_messages['message'] = $e->getMessage();
            $this->_errors[] = $e->getMessage();
            /*
             * Rollback the connections
             */
            $this->_integrationConnect->rollback();
        }

        /*
         * Process XML files
         */
        try {
            $numberAccounts = $this->getSalesOrdersCountMos();
            $bunchCountMos = ceil($numberAccounts/Config::$batchVariable);
            for($doLoopMos=1; $doLoopMos<=$bunchCountMos; $doLoopMos++) {

            $accounts = $this->getAccountsForMos();
            //$saleOrderXml = $this->getSalesOrdersForXml();
            /*
             * Update message array with number of sales orders.
             */
            $this->_messages['mos']['count'] = $numberAccounts;
            $msg = &$this->_messages['mos']['accounts'];

            while ($account = $accounts->fetch_object()) {
                try {
                    /*
                     * Disable auto commit.
                     */
                    syslog(
                            LOG_INFO, "Disabling auto commit"
                    );

                    Config::writelog('phpcronjob2', "Disabling auto commit");

                    $this->_integrationConnect->autocommit(FALSE);

                    $msg[$account->accountname]['status'] = false;

                    //$mosFile = $this->createMOSFile($account, $msg);
                    $xmlFile = $this->createXMLFile($account, $msg);

                    $this->storeFileInSThree(
                            Config::$amazonSThree['xmlBucket'], Config::$amazonSThree['xmlFolder'], $xmlFile['file'], $xmlFile['content']
                    );

                    $this->storeFileInMessageQ(
                            Config::$amazonQ['url'], json_encode($xmlFile)
                    );

                    $msg[$account->accountname]['status'] = true;
                    $fileName = $xmlFile['file'];

                    $this->updateIntegrationSalesOrderByAccountName(
                            $account->accountname, 'mos_status', 'Delivered'
                    );
                    /*
                     * Commit the databases.
                     */
                    $this->_integrationConnect->commit();
                } catch (Exception $e) {
                    $numberAccounts--;
                    $this->_errors[] = $e->getMessage();
                    /*
                     * Rollback the connections
                     */
                    $this->_integrationConnect->rollback();
                }
            }
           }
            $this->_messages['mos']['message'] = "$numberAccounts number " .
                    "of accounts processed for XML files.";
             $successMessage = "Total set file processed:".$numberSalesOrders 
             .PHP_EOL ."Total XML file processed:".$numberAccounts;       
            //$this->sendEmailAlertSuccess($successMessage);
        } catch (Exception $e) {
            $this->_messages['message'] = $e->getMessage();
            $this->_errors[] = $e->getMessage();
            
            /*
             * Rollback the connections
             */
            $this->_integrationConnect->rollback();
        }

        syslog(
                LOG_INFO, json_encode($this->_messages)
        );

        Config::writelog('phpcronjob2', json_encode($this->_messages));

        echo json_encode($this->_messages);
        if(count($this->_errors)>0) {
          //$this->sendEmailAlert($this->_errors);
        }
    }

}

class Functions {

    /**
     * auto adding zero before number  
     */
    static function leadingzero($limitnumber = 6, $number = 0) {
        $leadzero = "";
        $leadingzero = $limitnumber - $number;

        for ($i = 0; $i < $leadingzero; $i++) {
            $leadzero .= '0';
        }
        return $leadzero;
    }

    /*
     * Get 4 last digit from micro-time
     */

    static function getMilliSecond() {
        $seconds = round(microtime(true) * 1000);
        $remainder = substr("$seconds", -4);

        return $remainder;
    }

}

try {
    $phpBatchTwo = new PhpBatchTwo();
    $phpBatchTwo->init();
} catch (Exception $e) {
    syslog(LOG_WARNING, $e->getMessage());

    Config::writelog(LOG_WARNING, $e->getMessage());

    echo $e->getMessage();
}
