<?php

/**
 * @category   Integration
 * 
 * @package    Config
 * @subpackage DatabaseConfig
 * @author     Prabhat Khera <prabhat.khera@gmail.com>
 * @link       href="http://gizur.com"
 * @copyright  Copyright (c) 2012,Gizur AB, 
 * <a href="http://gizur.com">Gizur Consulting</a>.
 * @license    Commercial license
 * @version    SVN: $Id$
 * purpose : connect to mysql server
 * Coding standards:
 * http://pear.php.net/manual/en/standards.php
 * PHP version 5.3.2
 */

/**
 * 
 * Call Configration Files
 * 
 */
require_once __DIR__ . '/config.inc.php';

/**
 * 
 * ready state of syslog
 * 
 */
openlog("DatabaseConnetionCron", LOG_PID | LOG_PERROR, LOG_LOCAL0);

/**
 * 
 * Database Connection Class
 * 
 */
class Connect extends mysqli
{

    /**
     * Initialze the object with required properties
     */
    public function __construct($host, $user, $pass, $database)
    {
        parent::__construct(
            $host, $user, $pass, $database
        );
        if ($this->connect_errno) {
            syslog(
                LOG_WARNING, 'Error connecting ' . $host . ' (' .
                $this->connect_errno . ') ' .
                $this->connect_error
            );
            die('Error connecting ' . $host . ' (' .
                $this->connect_errno . ') '
                . $this->connect_error);
        }
    }

}