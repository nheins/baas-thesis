import subprocess
import sys
import time
import signal
import json
from pathlib import Path
from datetime import datetime
import csv

class WAFInterval:
    def __init__(self, device, name):
        self.attributes = None
        self.device = None
        self.log = []
        self.starttime = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.log_dir = Path(f"./waf_logs/{self.starttime}_{name}")
        self.log_dir.mkdir(parents=True, exist_ok=True)
    
    def get_smart_attributes(self, dev):
        """Get physical writes from SMART attributes"""
        cmd = ["smartctl", "-A", dev]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            smart_data = {
                'Total_LBAs_Written': None,
                'Host_Program_Page_Count': None,
                'FTL_Program_Page_Count': None
            }
            
            for line in result.stdout.split('\n'):
                for attribute in smart_data.keys():
                    if attribute in line:
                        smart_data[attribute] = int(line.split()[9])
            
            return smart_data
        except subprocess.CalledProcessError as e:
            print(f"Error getting SMART data: {e}")
            return None

    def start_interval(self):
        self.attributes = self.get_smart_attributes(dev)
        self.time_stamp = int(time.time())

    def lap_interval(self, last=False):
        timestamp = int(time.time())
        if last: time.sleep(1)
        attributes_now = self.get_smart_attributes(dev)
        normalized = {}
        for attr_name, attr_value in attributes_now.items():
            if attr_value is not None and self.attributes.get(attr_name) is not None:
                normalized[f"normalized_{attr_name}"] = attr_value - self.attributes[attr_name]
        
        self.log.append({
            'timestamp': timestamp,
            **attributes_now,
            **normalized,
        })
    
    def save_data(self):
        """Save collected data to files"""
        json_file = self.log_dir / f'{self.starttime}_smart.json'
        with open(json_file, 'w') as f:
            json.dump({
                'device': self.device,
                'data': self.log
            }, f, indent=2)
        print(f"\nSaved JSON data to {json_file}")
        
        csv_file = self.log_dir / f'{self.starttime}_smart.csv'
        with open(csv_file, 'w', newline='') as f:
            fieldnames = self.log[0].keys() if self.log else []
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(self.log)
        print(f"Saved CSV data to {csv_file}")

def signal_handler(signal, frame):
    global waf_int
    waf_int.lap_interval(last=True)
    waf_int.save_data()
    sys.exit(1)
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("arguments should be: DEVICE INTERVAL(seconds) NAME")
        sys.exit(1)
    dev = sys.argv[1]
    interval = int(sys.argv[2])
    name = sys.argv[3]

    waf_int = WAFInterval(dev, name)
    waf_int.start_interval()
    while True:
        try:
            time.sleep(interval)
            waf_int.lap_interval()
        except Exception as e:
            print(f"Error : {e}")
            sys.exit(1)

    sys.exit(0)