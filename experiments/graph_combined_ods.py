import pandas as pd
import matplotlib.pyplot as plt
import sys
from pyexcel_ods import get_data

def create_waf_comparison(file_path, output_file):
    # Read only the Combined sheet
    df = pd.read_excel(file_path, engine='odf', sheet_name='Combined')
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # Plot settings for each test
    styles = [
        ('tab:blue', 'o'),
        ('tab:orange', 's'),
        ('tab:green', '^'),
        ('tab:red', 'D')
    ]
    
    # Plot each WAF test
    for i, test_num in enumerate(['1', '2', '3', '4']):
        color, marker = styles[i]
        ax.plot(df['seconds'], df[f'WAF_Test-{test_num}'], 
                color=color, 
                marker=marker,
                markevery=20,  # Add marker every 20 points
                label=f'WAF Test {test_num}',
                markersize=8)
    
    ax.set_xlabel('Time [seconds]')
    ax.set_ylabel('WAF')
    ax.grid(True, linestyle='--', alpha=0.7)
    ax.legend(loc='upper left')
    
    plt.title('WAF Comparison Across Tests')
    plt.tight_layout()
    plt.savefig(output_file)
    plt.close()

if __name__ == "__main__":
    file_path = sys.argv[1]
    output_file = sys.argv[2]
    create_waf_comparison(file_path, output_file)