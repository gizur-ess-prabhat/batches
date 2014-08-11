<?php

/**
 * This file contains common functions used throughout the Integration package.
 *
 * @package    Integration
 * @subpackage Config
 * @author     Jonas Colmsjö <jonas.colmsjo@gizur.com>
 * @version    SVN: $Id$
 *
 * @license    Commercial license
 * @copyright  Copyright (c) 2012, Gizur AB, 
 * <a href="http://gizur.com">Gizur Consulting</a>, All rights reserved.
 *
 * Coding standards:
 * http://pear.php.net/manual/en/standards.php
 *
 * PHP version 5
 *
 */
/* * *************** INTEGRATION DATABASE ******************** */

/**
 * DNS of database server to use 
 * @global string $dbconfigIntegration['db_server']
 */
$dbconfigIntegration['db_server'] = 'gizurcloud.colm85rhpnd4.eu-west-1.' .
    'rds.amazonaws.com';

/**
 * The port of the database server
 * @global string $dbconfigIntegration['db_port']       
 */
$dbconfigIntegration['db_port'] = 3306;

/**
 * The usename to use when logging into the database
 * @global string $dbconfigIntegration['db_username']  
 */
$dbconfigIntegration['db_username'] = 'vtiger_integrati';

/**
 * The password to use when logging into the database
 * @global string $dbconfigIntegration['db_password']
 */
$dbconfigIntegration['db_password'] = 'ALaXEryCwSFyW5jQ';

/**
 * The name of the database
 * @global string $dbconfigIntegration['db_name']
 */
$dbconfigIntegration['db_name'] = 'vtiger_integration';

/**
 * The type of database (currently is only mysql supported)
 * @global string $dbconfigIntegration['db_type']
 */
$dbconfigIntegration['db_type'] = 'mysql';


/* * **************** VTIGER DATABASE *************** */


/**
 * DNS of database server to use 
 * @global string $dbconfigVtiger['db_server']
 */
$dbconfigVtiger['db_server'] = 'gizurcloud.colm85rhpnd4.eu-west-1.' .
    'rds.amazonaws.com';

/**
 * The port of the database server
 * @global string $dbconfigVtiger['db_port']       
 */
$dbconfigVtiger['db_port'] = 3306;

/**
 * The usename to use when logging into the database
 * @global string $dbconfigVtiger['db_username']  
 */
$dbconfigVtiger['db_username'] = 'user_6bd70dc31';

/**
 * The password to use when logging into the database
 * @global string $dbconfigVtiger['db_password']
 */
$dbconfigVtiger['db_password'] = 'fbd70dc30c051';

/**
 * The name of the database
 * @global string $dbconfigVtiger['db_name']
 */
$dbconfigVtiger['db_name'] = 'vtiger_7cd70dc3';

/**
 * The type of database (currently is only mysql supported)
 * @global string $dbconfigVtiger['db_type']
 */
$dbconfigVtiger['db_type'] = 'mysql';



/* * ************* BATCH CONFIGURATION ************* */

/**
 *  Set Batch Variable
 * 
 * 
 */
$dbconfigBatchVariable['batch_variable'] = 10;

/* * *************** FTP CONFIGURATION ************* */


/**
 *  @FTP Host Name 
 */
$dbconfigFtp['Host'] = "ftp.essindia.net";


/**
 *  @FTP Host Port 
 */
$dbconfigFtp['port'] = 21;

/**
 *  @FTP User Name 
 */
$dbconfigFtp['User'] = "hypermart@essindia.net";


/**
 *  @FTP Password
 */
$dbconfigFtp['Password'] = "zmLA_Q#A9EK2";

/**
 *  @FTP Local files path
 */
$dbconfigFtp['localpath'] = "cronsetfiles/";

/**
 *  @FTP Server files path
 */
$dbconfigFtp['serverpath'] = "/demo-in/";


/** * ******************* Amazon SQS Configuration ********************** * */
/**
 * Queue URL
 */
$amazonqueueConfig['_url'] = 'https://sqs.eu-west-1.amazonaws.com/' .
    '065717488322/cikab_queue';

/*
 * Amazon S3 Bucket
 */
$amazonSThree['bucket'] = "gc3-archive";
$amazonSThree['fileFolder'] = "seasonportal/SET-files/";

class Config
{

    public static $dbIntegration = array(
        'db_server' => 'gizurcloud.colm85rhpnd4.eu-west-1.rds.amazonaws.com',
        'db_port' => 3306,
        'db_username' => 'vtiger_integrati',
        'db_password' => 'ALaXEryCwSFyW5jQ',
        'db_name' => 'vtiger_integration',
        'db_type' => 'mysql'
    );
    public static $dbVtiger = array(
        'db_server' => 'gizurcloud.colm85rhpnd4.eu-west-1.rds.amazonaws.com',
        'db_port' => 3306,
        'db_username' => 'user_6bd70dc3',
        'db_password' => 'fbd70dc30c05',
        'db_name' => 'vtiger_7cd70dc3',
        'db_type' => 'mysql'
    );
    public static $batchVariable = 5;
     public static $setFtp = array(
        'host' => "ftp.essindia.net",
        'port' => 21,
        'username' => "hypermart@essindia.net",
        'password' => "zmLA_Q#A9EK2",
        'serverpath' => "/demo-in/"
    );
    public static $mosFtp = array(
        'host' => "ftp.essindia.net",
        'port' => 21,
        'username' => "hypermart@essindia.net",
        'password' => "zmLA_Q#A9EK2",
        'serverpath' => "/demo-in/"
    );
    public static $amazonQ = array(
        'url' => 'https://sqs.eu-west-1.amazonaws.com/065717488322/cikab_queue'
    );
    public static $amazonSThree = array(
        'setBucket' => "gc3-archive",
        'setFolder' => "seasonportal/SET-files/",
        'mosBucket' => "gc3-archive",
        'mosFolder' => "seasonportal/SET-files/",
        'xmlBucket' => "gc3-archive",
        'xmlFolder' => "seasonportal/XML-files/"
    );
    public static $customFields = array(
        'setFiles' => 'cf_650',
        'mosFiles' => 'cf_651',
        'basProductId' => 'cf_652'
    );
    public static $lineBreak = "\r\n";
    public static $toEmailReports = array(
        "rohit.kumar@essindia.co.in"
    );
    public static $toEmailErrorReports = array(
        "rohit.kumar@essindia.co.in"
    );
  static function writelog($file_name, $message)
    {
        $logfile = __DIR__ . '/log/log_' . date("j.n.Y") . '.txt';
//implicitly creates file
        if (!file_exists($logfile)) {
            exec('touch ' . $logfile);
            exec('chmod 777 ' . $logfile);
        }

//Something to write to txt log
        $log = "User: Cloud1 - " . date("F j, Y, g:i a") . PHP_EOL .
            "File: " . $file_name . PHP_EOL .
            "Message: " . $message . PHP_EOL .
            "-------------------------" . PHP_EOL;

//Save string to log, use FILE_APPEND to append.
        file_put_contents($logfile, $log, FILE_APPEND);
    }
}
