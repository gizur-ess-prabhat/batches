#!/bin/bash
supervisord
tail -f /var/log/supervisor/supervisord.log
