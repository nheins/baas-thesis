import argparse
import json
import time
import psutil
import pandas as pd
import subprocess
from datetime import datetime
from pathlib import Path

class SSDMonitor:
    def __init__(self, device_path, output_dir):
        """
        Initialize SSD monitoring for a specific device
        
        Args:
            device_path (str): Path to device (e.g., '/dev/sda')
            output_dir (str): Directory to store monitoring data (gets created if it doesn't exist)
        """

        self.device_path = device_path
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.current_session = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.data = []
  
    def get_smart_attributes(self):
        """Get SMART attributes using smartctl"""
        try:
            cmd = ["smartctl", "-A", "-j", self.device_path]
            result = subprocess.run(cmd, capture_output=True, text=True)
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            print(f"Error getting SMART attributes: {e}")
            return None

    def get_measurements(self):
        """
        Get current write bytes and write time
        """
        disk_io = psutil.disk_io_counters(perdisk=True)
        device_name = self.device_path.split('/')[-1]
        if device_name in disk_io:
            stats = disk_io[device_name]
            timestamp = datetime.now()                    
            entry = {
                'timestamp': timestamp,
                'write_bytes': stats.write_bytes,
                'write_count': stats.write_count,
                'write_time': stats.write_time
            }
            self.data.append(entry)

    def monitor_writes(self, interval):
        """
        Monitor metrics in intervals and saves to device on exit
        
        Args:
            interval (int): Monitoring interval in seconds
        """
        
        while True:
            try:
                self.get_measurements()   

                # Save data periodically to reduce i/o operations
                if len(self.data) % 10 == 0:                    
                    self.save_data()

                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\nStopping monitoring...")
                self.get_measurements()
                self.save_data()
                break

    def save_data(self):
        """Save collected data to files"""        
        # TODO append or write complete data all the time?
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        print("Saving data...")
        
        json_path = self.output_dir / f"raw_data_{self.current_session}.json"
        with open(json_path, 'w') as f:
            json.dump(self.data, f, default=str)
        
        df = pd.DataFrame([{
            'timestamp': d['timestamp'],
            'write_bytes': d['write_bytes'],
            'write_count': d['write_count'],
            'write_time': d['write_time'],
            'smart_data': self.get_smart_attributes(),
        } for d in self.data])

        csv_path = self.output_dir / f"metrics_{self.current_session}.csv"
        df.to_csv(csv_path, index=False)

def main():
    parser = argparse.ArgumentParser(description='Monitor SSD wear')
    parser.add_argument('--device', required=True, help='Device path (e.g., /dev/sda)')
    parser.add_argument('--output', required=True, help='Output directory for monitoring data')
    parser.add_argument('--interval', type=int, default=3, help='Monitoring interval in seconds')
    args = parser.parse_args()
    
    monitor = SSDMonitor(args.device, args.output)
    monitor.monitor_writes(interval=args.interval)

if __name__ == "__main__":
    main()