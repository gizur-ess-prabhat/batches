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
 * Load the configuration files.
 */

require_once __DIR__ . '/../config.inc.php';
require_once __DIR__ . '/../aws-php-sdk/sdk.class.php';

class PhpBatchThree
{
    private $_integrationConnect;
    private $_messages = array();
    private $_messageCount = 0;
    private $_noOfFiles = 0;
    private $_setFtpConn;
    private $_mosFtpConn;
    private $_sqs;
    private $_errors = array();

    function __construct()
    {
       /*
         * Trying to connect to integration database
         */
        $this->_integrationConnect = new mysqli(
            Config::$dbIntegration['db_server'],
            Config::$dbIntegration['db_username'],
            Config::$dbIntegration['db_password'],
            Config::$dbIntegration['db_name'],
            Config::$dbIntegration['db_port']
        );

        if ($this->_integrationConnect->connect_errno) {
            throw new Exception('Unable to connect with integration DB');
                Config::writelog('phpcronjob3','Unable to connect with integration DB');
         }
        syslog(
            LOG_INFO, "Connected with integration db"
        );
        Config::writelog('phpcronjob3','Connected with integration db');

        /*
         * Open connection to the system logger
         */
        openlog(
            "phpcronjob3", LOG_PID | LOG_PERROR, LOG_LOCAL0
        );
        
    /*
     * Trying to connect to SQS
     */            
         Config::writelog('phpcronjob3', "Trying connecting with Amazon SQS");

        syslog(
            LOG_INFO, "Trying connecting with Amazon SQS"
        );

        $this->_sqs = new AmazonSQS();
        
         Config::writelog('phpcronjob3', "Trying connecting with Amazon SQS");

        syslog(
            LOG_INFO, "Connected with Amazon SQS"
        );
        
         syslog(
                LOG_INFO, "Trying connecting with Amazon SES"
        );

        Config::writelog('phpcronjob3', "Trying connecting with Amazon SES");

        $this->_ses = new AmazonSES();

        syslog(
                LOG_INFO, "Connected with Amazon SES"
        );
        Config::writelog('phpcronjob3', "Connected with Amazon SES");

        $this->_setFtpConn = $this->getftpConnection(
            Config::$setFtp['host'], 
            Config::$setFtp['port'], 
            Config::$setFtp['username'], 
            Config::$setFtp['password']
        );

        $this->_mosFtpConn = $this->getftpConnection(
            Config::$mosFtp['host'], 
            Config::$mosFtp['port'],
            Config::$mosFtp['username'],
            Config::$mosFtp['password']
        );
    }

    /*
     *  Creating connection with ftp server
     */    
    protected function getftpConnection(
    $host, $port, $username, $password, $timeout = 10
    )
    {
        /**
         * Check FTP Connection
         */
        $ftpConn = ftp_connect(
            $host, $port, $timeout
        );

        /**
         * If connection fails update syslog with 
         * the error message and display
         * an error message.
         */
        if (!$ftpConn) {
            $syslogmessage = "Some problem in FTP Connection ($host:$port). " .
                "Please check Host Name!";
            syslog(
                LOG_WARNING, $syslogmessage
            );
             Config::writelog('phpcronjob3',  $syslogmessage);
            throw new Exception($syslogmessage);
        }

        /**
         *  Check Authentication after connection
         */
        $ftpLoginResult = ftp_login(
            $ftpConn, $username, $password
        );
        /**
         * If authentication fails update the syslog.
         */
        if (!$ftpLoginResult) {
            $syslogmessage = "Some problem in FTP Connection ($host:$port)" .
                ". Please check username and password!";
            syslog(
                LOG_WARNING, $syslogmessage
            );
             Config::writelog('phpcronjob3',  $syslogmessage);
            throw new Exception($syslogmessage);
        }

        /*
         * Enable passive mode
         */
        ftp_pasv($ftpConn, true);

        /**
         * Check FTP Connection and Authenticate the connection again
         */
        if (!$ftpConn || !$ftpLoginResult) {
            $syslogmessage = "Some problem in FTP Connection ($host:$port)!";
             Config::writelog('phpcronjob3',  $syslogmessage);
            syslog(
                LOG_WARNING, $syslogmessage
            );
            throw new Exception($syslogmessage);
        }

        return $ftpConn;
    }

    /*
     * Store file in FTP
     */    
    protected function saveToFtp($ftpConnId, $serverpath, $fileJson)
    {
        $ftpPath = $serverpath . $fileJson->file;

        /*
         * If file exists at FTP, raise the Exception.
         */
        if (ftp_size($ftpConnId, $ftpPath) != -1) {
            syslog(
                LOG_WARNING,
                "$fileJson->file file already exists at FTP server."
            );
             Config::writelog('phpcronjob3', "$fileJson->file file already exists at FTP server.");
            throw new Exception(
                "$fileJson->file file already exists at FTP server."
            );
        }

        /*
         * Prepare file in temp dir locally.
         */
        $fp = fopen('php://temp', 'r+') or die("can't open file");
       
        $fwstatus = fwrite($fp, $fileJson->content);
        if(!$fwstatus) {
        syslog(
                LOG_WARNING, "Error to write file."
            );
             Config::writelog('phpcronjob3', "Error to write file.");
            throw new Exception(
                "Error to write file."
            );
        }
        $rewindStatus = rewind($fp);
        if(!$rewindStatus) {
        syslog(
                LOG_WARNING, "Error to rewind file."
            );
             Config::writelog('phpcronjob3', "Error to rewind file.");
            throw new Exception(
                "Error to rewind file."
            );
        }
        /*
         * Upload file to FTP.
         */
        $uploaded = ftp_fput(
            $ftpConnId, $ftpPath, $fp, FTP_BINARY
        );

        fclose($fp);
        /*
         * If file upload process fails, throw the exception.
         */
        if (!$uploaded) {
            syslog(
                LOG_WARNING, "Error copying file $fileJson->file on FTP server."
            );
             Config::writelog('phpcronjob3', "Error copying file $fileJson->file on FTP server.");
            throw new Exception(
                "Error copying file $fileJson->file on FTP server."
            );
        }

        return $uploaded;
    }

    /*
    *Saving successful transfer order in db
    */
    protected function saveToDbTable($fileJson) {
            $filename= $fileJson->file;
            $created= date('Y-m-d h:i:s');
            $updated= date('Y-m-d h:i:s');
            $st='P';
             $salesOrdersQuery = "INSERT INTO salesorder_message_queue(filename, created, updated, status) values('$filename','$created', '$updated', '$st')";
             $salesOrders = $this->_integrationConnect->query($salesOrdersQuery);
            if(!$salesOrders) {
            Config::writelog('phpcronjob3',"Error Query to save messages in database".$salesOrdersQuery);
             throw new Exception(
                            "Error Query to save messages in database".$salesOrdersQuery
                        );

           }
     }
     
     /*
    *Updating successful transfer order in db
    */
     protected function updateToDbTable($fileJson) {
        $filename= $fileJson->file;
        $created= date('Y-m-d h:i:s');
        $updated= date('Y-m-d h:i:s');
        $st='P';
        // Update salesorder_message_queue table
         $salesOrdersQuery = "UPDATE salesorder_message_queue set status='D', updated='$updated'   WHERE fileName='$filename'";
         $salesOrders = $this->_integrationConnect->query($salesOrdersQuery);
        if(!$salesOrders) {
        Config::writelog('phpcronjob3', "Error Query to update messages in database".$salesOrdersQuery);
         throw new Exception(
                        "Error Query to update messages in database".$salesOrdersQuery
                    );

       }
     }
     /*
     * Fetch successfully delivered sales order from integration db.
     */
     function getDeliveredSalesOrder() {
          $dt= date('Y-m-d');
          $salesOrdersQueryD = "SELECT id  FROM salesorder_message_queue ".
          "WHERE updated like'%$dt%' AND status='D'";
          $salesOrdersD = $this->_integrationConnect->query($salesOrdersQueryD);
          if(!$salesOrdersD) {
          Config::writelog('phpcronjob3', "getDeliveredSalesOrder() Error Query to fetch delivered sales order".$salesOrdersD);
            throw new Exception(
                        "getDeliveredSalesOrder() Error Query to fetch delivered sales order".$salesOrdersD
                    );

        }
          if($salesOrdersD->num_rows==0) {
            syslog(
                    LOG_WARNING, "In getDeliveredSalesOrder() : No delivered Sales Order Found!"
            );
            Config::writelog('phpcronjob3', "In getDeliveredSalesOrder() : No delivered Sales Order Found!");
            throw new Exception("In getDeliveredSalesOrder() : No delivered Sales Order Found!");
          }
          return $salesOrdersD->num_rows;
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
       $messages = implode(', ',$errorMessage);
       $sesResponseAlert = $this->_ses->send_email(
        "noreply@gizur.com",
        array(
           "ToAddresses" => Config::$toEmailErrorReports
        ),
        array(
            'Subject.Data'=>"Alert! Error arose during sales order processed Cronjon-3",
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
                   Config::writelog('phpcronjob3', "Some error to sent mail");

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
            'Subject.Data'=>"Sales order processed from SQS Cronjon-3",
            'Body.Text.Data'=>"Hi,". PHP_EOL .
            "Total no of sales order successfully processed from SQS". PHP_EOL . PHP_EOL .
            " ".$successMessage .PHP_EOL .
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
                   Config::writelog('phpcronjob3', "Some error to sent mail");

        }
    }

    public function init()
    {
        $this->_messageCount = $this->_sqs->get_queue_size(
            Config::$amazonQ['url']
        );
        $this->_noOfFiles = $this->_messageCount;


        /*
         * If number of files are 0, throw the exception
         */
        if ($this->_messageCount <= 0) {
            syslog(
                LOG_INFO, "message queue is empty."
            );
             Config::writelog('phpcronjob3', "message queue is empty.");
            throw new Exception("message queue is empty.");
        }
        /*
         * Iterate till $_messageCount becomes 0.
         */
        syslog(
            LOG_INFO, 
            "Number of messages found in message queue : $this->_messageCount."
        );
         Config::writelog('phpcronjob3', "Number of messages found in message queue : $this->_messageCount.");
            
        while ($this->_messageCount > 0) {
            /*
             * Inner try catch to catch the message specific exceptions.
             */
            try {
                /*
                 * Get the single message from the message queue.
                 */
                syslog(
                    LOG_INFO,
                    "Get the single message from the message queue"
                );
                
                 Config::writelog('phpcronjob3', "Get the single message from the message queue");
                $responseQ = $this->_sqs->receive_message(
                    Config::$amazonQ['url']
                );
                
                /*
                 * If response is 200, Throw exception.
                 */
                if ($responseQ->status !== 200) {
                    syslog(
                        LOG_INFO, 
                        "Message not received from the message queue server"
                    );
                     Config::writelog('phpcronjob3',"Message not received from the message queue server");
                    throw new Exception(
                        "Message not received from the message queue server."
                    );
                }

                syslog(
                    LOG_INFO, 
                    "Message received from the message queue server"
                );
                 Config::writelog('phpcronjob3', "Message received from the message queue server");
                /*
                 * Get the message body.
                 */
                $msgObj = $responseQ->body->ReceiveMessageResult->Message;
                /*
                 * If message body is empty, raise the exception.
                 */
                if (empty($msgObj)) {
                    syslog(
                        LOG_INFO, "Received an empty message from message queue."
                    );
                     Config::writelog('phpcronjob3', "Received an empty message from message queue.");
                    throw new Exception(
                        "Received an empty message from message queue."
                    );
                }
                $msgBody = (array)$msgObj->Body;
                $msgBody = $msgBody[0];
                
                syslog(
                    LOG_INFO, "Message Received: " . $msgBody
                );
                 Config::writelog('phpcronjob3', "Message Received: " . $msgBody);

                /*
                 * File name and content were json encoded so decode it.
                 */
                
                $fileJson = json_decode($msgBody);
                if(!is_object($fileJson))
                    $fileJson = json_decode($fileJson);
                //print_r($fileJson); die;
                /*
                 * Get the message receipt
                 */
                $receiptQ = (array)$msgObj->ReceiptHandle;
                $receiptQ = (string)$receiptQ[0];
                
                /*
                 * If file content are empty raise the exception.
                 */
                if (empty($fileJson->content)) {
                    syslog(
                        LOG_WARNING,
                        "$fileJson->file content is empty in message queue."
                    );
                     Config::writelog('phpcronjob3', "$fileJson->file content is empty in message queue.");
                    throw new Exception(
                        "$fileJson->file content is empty in message queue."
                    );
                }
            // Save Sqs message in database
                     $this->saveToDbTable($fileJson);
            // End save messages database
                if ($fileJson->type == 'SET' || !isset($fileJson->type)) {
                 $st =   $this->saveToFtp(
                        $this->_setFtpConn,
                        Config::$setFtp['serverpath'],
                        $fileJson
                    );
                    if($st) {
                          $this->updateToDbTable($fileJson);
                     }

                } else if ($fileJson->type == 'XML') {
                    $st = $this->saveToFtp(
                        $this->_mosFtpConn,
                        Config::$mosFtp['serverpath'],
                        $fileJson
                    );
                    if($st) {
                          $this->updateToDbTable($fileJson);
                     }
                }
                /*
                 * Delete message from message queue.
                 */
                syslog(
                    LOG_INFO, 
                    "Deleting message from message queue : $fileJson->file."
                );
                 Config::writelog('phpcronjob3', "Deleting message from message queue : $fileJson->file.");
                $deletedmessage=$this->_sqs->delete_message(
                    Config::$amazonQ['url'], $receiptQ
                );
                $deletedmessages=json_encode($deletedmessage);
                syslog(
                    LOG_INFO, 
                    "Deleted message Response : $deletedmessages"
                );
                Config::writelog('phpcronjob3', "Deleted message Response : $deletedmessages");
                if ($deletedmessage->status !== 200) {
                    syslog(
                        LOG_INFO, 
                        "Message has not deleted successfully."
                    );
                     Config::writelog('phpcronjob3',"Message has not deleted successfully.");
                    throw new Exception(
                        "Message has not deleted successfully."
                    );
                }
                $this->_messages['files'][$fileJson->file]['status'] = true;
            } catch (Exception $e) {
                $this->_messages['files'][$fileJson->file]['status'] = false;
                $this->_messages['files'][$fileJson->file]['error'] = 
                    $e->getMessage();
                     $this->_errors[] = $e->getMessage();
            }
            /*
             * Decrease $_messageCount by 1
             */
            $this->_messageCount--;
        }
        if($this->getDeliveredSalesOrder() != $this->_noOfFiles) {
          syslog(
                    LOG_INFO, 
                    "Error successfully delivered sales: ".$this->getDeliveredSalesOrder(). 
                    " and total fetched messages from sqs: $this->_noOfFiles are different!  "
                );
                 Config::writelog('phpcronjob3', "Error successfully delivered sales: 
                 ".$this->getDeliveredSalesOrder()." and total fetched messages from sqs:
                 "." $this->_noOfFiles  are different!  ");
                 $this->_errors[] = "Error successfully delivered sales: ".$this->getDeliveredSalesOrder(). 
                    " and total fetched messages from sqs: $this->_noOfFiles  are different!  ";
        }
        $this->_messages['message'] = "$this->_noOfFiles no " .
            "of files processed.";
            $this->sendEmailAlertSuccess("$this->_noOfFiles" .
            " Files");
        syslog(
            LOG_INFO, json_encode($this->_messages)
        );
         Config::writelog('phpcronjob3', json_encode($this->_messages));
        echo json_encode($this->_messages);
        if(count($this->_errors)>0) {
         //$this->sendEmailAlert($this->_errors);
        }
    }
}

try{
    $phpBatchThree = new phpBatchThree();
    $phpBatchThree->init();
}catch(Exception $e){
    syslog(LOG_WARNING, $e->getMessage());
    Config::writelog('phpcronjob3', $e->getMessage());
    echo $e->getMessage();
   // $this->sendEmailAlert($e->getMessage());
}
