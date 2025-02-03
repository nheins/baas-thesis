import pandas as pd
import matplotlib.pyplot as plt
import sys
from pyexcel_ods import get_data

def create_dual_axis_graph(file_path, file):
    df = pd.read_excel(file_path, engine='odf')
    
    fig, ax1 = plt.subplots(figsize=(12, 6))
    
    # WAF plot
    color = 'tab:blue'
    ax1.set_xlabel('Time [seconds]')
    ax1.set_ylabel('WAF', color=color)
    ax1.set_ylim(top=1.4)
    line1 = ax1.plot(df['seconds'], df['WAF'], color=color, label='WAF')
    ax1.tick_params(axis='y', labelcolor=color)
    ax1.grid(True, axis='y', linestyle='--', alpha=0.7)
    
    # GB Written plot - now using seconds as x-axis
    ax2 = ax1.twinx()
    color = 'tab:red'
    ax2.set_ylabel('Gigabyte', color=color)
    line2 = ax2.plot(df['seconds'], df['Total_Gigabytes_written'], color=color, label='total Gigabytes written')
    ax2.tick_params(axis='y', labelcolor=color)
    
    # Set same x-axis limits for both plots
    ax1.set_xlim(df['seconds'].min(), df['seconds'].max())
    
    lines = line1 + line2
    labels = [l.get_label() for l in lines]
    ax1.legend(lines, labels, loc='upper left')
    
    plt.title('WAF and GB written over time')
    plt.tight_layout()
    plt.savefig(file)
    plt.close()

if __name__ == "__main__":
    file_path = sys.argv[1]
    file = sys.argv[2]
    create_dual_axis_graph(file_path,file)