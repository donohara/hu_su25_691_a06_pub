import logging
import json
from logging.handlers import RotatingFileHandler

LOG_FILE = "grantguru.log"

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "funcName": record.funcName,
        }
        return json.dumps(log_entry)

def setup_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)

    # Console Handler
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(JSONFormatter())

    # Rotating File Handler
    fh = RotatingFileHandler(LOG_FILE, maxBytes=5 * 1024 * 1024, backupCount=2)
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(JSONFormatter())

    logger.addHandler(ch)
    logger.addHandler(fh)
    logger.propagate = False

    return logger
