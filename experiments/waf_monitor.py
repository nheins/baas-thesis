#!/home/nico/Projects/baas-thesis/experiments/.venv/bin/python
import subprocess
import time
import json
import signal
import argparse
from datetime import datetime
from pathlib import Path
import csv
import psutil

class WAFMonitor:
    def __init__(self, device, fio_job_file, experiment_name, interval=1):
        self.device = device
        self.device_name = self.device.split('/')[-1]
        self.fio_job_file = fio_job_file
        self.interval = interval
        self.log = []
        self.starttime = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.log_dir = Path(f"./waf_logs/{experiment_name}")
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.fio_log = self.log_dir / f"{self.starttime}"
        self.running = True
        
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

    def signal_handler(self, signum, frame):
        print("\nShutting down gracefully...")
        self.running = False

    def get_smart_attributes(self):
        """Get physical writes from SMART attributes"""
        cmd = ["smartctl", "-A", self.device]
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
        
    def get_os_measurements(self):
        """
        Get current write bytes and write time from psutil (for comparison to smartctl data)
        It'll take data from the OS https://www.kernel.org/doc/html/latest/admin-guide/iostats.html
        """
        try:
            disk_io = psutil.disk_io_counters(perdisk=True)
            if self.device_name in disk_io:
                stats = disk_io[self.device_name]                 
                os_data = {
                    'os_write_bytes': stats.write_bytes,
                    'os_write_count': stats.write_count,
                    'os_write_time': stats.write_time,
                }
                return os_data
        except Exception as e:
            print(f"Error getting OS data: {e}")
            return None
    

    def start_fio(self):
        """Start FIO in the background"""
        cmd = [
            "fio",
            f"--filename={self.device}",
            "--output-format=json",
            f"--output={self.fio_log}.json",
            f"--write_bw_log={self.fio_log}",
            f"--write_iops_log={self.fio_log}",
            "--log_avg_msec=1000",
            self.fio_job_file,
        ]
        return subprocess.Popen(cmd, text=True, stdout=subprocess.PIPE)

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

    def monitor(self):
        """Main monitoring loop"""
        print(f"Starting monitoring on device {self.device}")
        start_time = time.time()
        
        # Start FIO
        fio_process = self.start_fio()
        
        try:
            # Monitor while FIO is running
            while self.running and fio_process.poll() is None:
                timestamp = int(time.time())
                smart_data = self.get_smart_attributes()
                os_data = self.get_os_measurements()

                elapsed = int(timestamp - start_time)
                
                if smart_data is not None:
                    self.log.append({
                        'timestamp': timestamp,
                        **smart_data,
                        # **os_data,
                    })
                
                print(f"\rRunning FIO for {elapsed}s")
                time.sleep(self.interval)

            # Continue monitoring for 20 more seconds after FIO completes
            post_fio_start = time.time()
            while self.running and (time.time() - post_fio_start) < 20:
                timestamp = int(time.time())
                smart_data = self.get_smart_attributes()
                os_data = self.get_os_measurements()

                elapsed = int(timestamp - start_time)
                
                if smart_data is not None:
                    self.log.append({
                        'timestamp': timestamp,
                        **smart_data,
                        # **os_data,
                    })
                
                print(f"\rFIO completed. Post-monitoring: {int(time.time() - post_fio_start)}s/20s (Total runtime: {elapsed}s)")
                time.sleep(self.interval)

        finally:
            # Clean up FIO process if it's still running
            if fio_process.poll() is None:
                fio_process.terminate()
                fio_process.wait()
            
            print("\nSaving collected data...")
            self.save_data()


def main():
    parser = argparse.ArgumentParser(description='Monitor WAF and run FIO tests')
    parser.add_argument('device', help='Device path (e.g., /dev/sda1)')
    parser.add_argument('fio_job_file', help='FIO job file to run')
    parser.add_argument('--name',
                       help='Name for this experiment run',
                       default="")
    parser.add_argument('--interval', 
                       type=int,
                       default=1,
                       help='Monitoring interval in seconds')
    
    args = parser.parse_args()
    
    monitor = WAFMonitor(args.device, args.fio_job_file, f"{datetime.now().strftime("%Y-%m-%d_%H-%M")}_{args.name}", args.interval)
    monitor.monitor()

if __name__ == "__main__":
    main()