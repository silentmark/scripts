import { BaseApplicationCustomizer } from '@microsoft/sp-application-base';
import { AadHttpClient, HttpClientResponse } from '@microsoft/sp-http';

import { API_CONFIG } from './constants';

export interface IWhoAmIApplicationCustomizerProperties {
  webApi?: string;
}

export default class WhoAmIApplicationCustomizer
  extends BaseApplicationCustomizer<IWhoAmIApplicationCustomizerProperties> {

  private _floatingElement: HTMLElement | null = null;

  public async onInit(): Promise<void> {
    this._createFloatingElement();
    await this._callWhoAmIApi();
  }

  private _createFloatingElement(): void {
    if (this._floatingElement) {
      this._floatingElement.remove();
    }

    this._floatingElement = document.createElement('div');
    this._floatingElement.id = 'whoami-floating-widget';
    this._floatingElement.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 20px;
      background: #ffffff;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      padding: 16px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      z-index: 1000;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      font-size: 14px;
      color: #333;
      min-width: 200px;
      transition: all 0.3s ease;
    `;

    this._showLoadingContent();
    document.body.appendChild(this._floatingElement);
  }

  private _showLoadingContent(): void {
    if (!this._floatingElement) return;
    this._floatingElement.innerHTML = `
      <div style="display: flex; align-items: center; gap: 12px;">
        <div style="
          width: 20px;
          height: 20px;
          border: 2px solid #f3f3f3;
          border-top: 2px solid #0078d4;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        "></div>
        <span style="color: #666;">Loading user info...</span>
      </div>
      <style>
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      </style>
    `;
  }

  private _showUserContent(userName: string): void {
    if (!this._floatingElement) return;
    this._floatingElement.innerHTML = `
      <div>
        <div style="
          font-weight: 600;
          margin-bottom: 8px;
          color: #0078d4;
        ">Hello, ${this._escapeHtml(userName)}!</div>
        <button 
          id="whoami-action-button"
          style="
            background: #0078d4;
            color: white;
            border: none;
            border-radius: 4px;
            padding: 8px 16px;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            transition: background-color 0.2s ease;
          "
          onmouseover="this.style.backgroundColor='#106ebe'"
          onmouseout="this.style.backgroundColor='#0078d4'"
        >Show Details</button>
      </div>
    `;

    const button = this._floatingElement.querySelector('#whoami-action-button') as HTMLButtonElement;
    if (button) {
      button.addEventListener('click', () => this._handleButtonClick(userName));
    }
  }

  private _showErrorContent(errorMessage: string): void {
    if (!this._floatingElement) return;
    this._floatingElement.innerHTML = `
      <div>
        <div style="
          color: #d13438;
          font-weight: 600;
          margin-bottom: 8px;
        ">⚠ Error Loading User</div>
        <div style="
          font-size: 12px;
          color: #666;
          margin-bottom: 8px;
        ">${this._escapeHtml(errorMessage)}</div>
        <button 
          id="whoami-retry-button"
          style="
            background: #d13438;
            color: white;
            border: none;
            border-radius: 4px;
            padding: 8px 16px;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            transition: background-color 0.2s ease;
          "
          onmouseover="this.style.backgroundColor='#b02e31'"
          onmouseout="this.style.backgroundColor='#d13438'"
        >Retry</button>
      </div>
    `;
  }

  private async _handleButtonClick(userName: string): Promise<void> {
      try {
        const apiBaseUrl = this.properties.webApi || API_CONFIG.PRODUCTION_URL;
        const apiUrl = `https://${apiBaseUrl}/api/whoami`;
        
        const aadHttpClient: AadHttpClient = await this.context.aadHttpClientFactory.getClient(API_CONFIG.APP_ID);
        const response: HttpClientResponse = await aadHttpClient.post(apiUrl, AadHttpClient.configurations.v1, {});
        
        if (response.ok) {
          const content: string[] = await response.json();
          this._showDetailedContent(content);
        } else {
          this._showErrorContent(`HTTP ${response.status}: ${response.statusText}`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        this._showErrorContent(`Error loading details: ${errorMessage}`);
      }
    }

    private _showDetailedContent(content: string[]): void {
      if (!this._floatingElement) return;

      const listItems = content.map(item => 
        `<li style="
          padding: 8px 0;
          border-bottom: 1px solid #f0f0f0;
          color: #333;
        ">${this._escapeHtml(item)}</li>`
      ).join('');

      this._floatingElement.innerHTML = `
        <div>
          <div style="
            font-weight: 600;
            margin-bottom: 12px;
            color: #0078d4;
            display: flex;
            align-items: center;
            gap: 8px;
          ">
            <span>📋</span>
            User Details
          </div>
          <ul style="
            list-style: none;
            padding: 0;
            margin: 0 0 12px 0;
            max-height: 200px;
            overflow-y: auto;
            background: #f8f9fa;
            border-radius: 4px;
            padding: 8px;
          ">
            ${listItems}
          </ul>
          <div style="display: flex; gap: 8px;">
            <button 
              id="whoami-back-button"
              style="
                background: #6c757d;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 6px 12px;
                cursor: pointer;
                font-size: 11px;
                font-weight: 500;
                flex: 1;
                transition: background-color 0.2s ease;
              "
              onmouseover="this.style.backgroundColor='#5a6268'"
              onmouseout="this.style.backgroundColor='#6c757d'"
            >← Back</button>
            <button 
              id="whoami-refresh-button"
              style="
                background: #28a745;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 6px 12px;
                cursor: pointer;
                font-size: 11px;
                font-weight: 500;
                flex: 1;
                transition: background-color 0.2s ease;
              "
              onmouseover="this.style.backgroundColor='#218838'"
              onmouseout="this.style.backgroundColor='#28a745'"
            >🔄 Refresh</button>
          </div>
        </div>
      `;

      const backButton = this._floatingElement.querySelector('#whoami-back-button') as HTMLButtonElement;
      const refreshButton = this._floatingElement.querySelector('#whoami-refresh-button') as HTMLButtonElement;

      if (backButton) {
        backButton.addEventListener('click', async () => {
          await this._callWhoAmIApi();
        });
      }

      if (refreshButton) {
        refreshButton.addEventListener('click', async () => {
          const userName = content.length > 0 ? content[0] : 'User';
          await this._handleButtonClick(userName);
        });
      }
    }

  private _escapeHtml(text: string): string {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  private async _callWhoAmIApi(): Promise<void> {
    try {
      const apiBaseUrl = this.properties.webApi || API_CONFIG.PRODUCTION_URL;
      const apiUrl = `https://${apiBaseUrl}/api/whoami/name`;
      
      const aadHttpClient: AadHttpClient = await this.context.aadHttpClientFactory.getClient(API_CONFIG.APP_ID);
      const response: HttpClientResponse = await aadHttpClient.get(apiUrl, AadHttpClient.configurations.v1);

      if (response.ok) {
        const userName: string = await response.text();
        this._showUserContent(userName);
      } else {
        this._showErrorContent(`HTTP ${response.status}: ${response.statusText}`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      this._showErrorContent(`Network error: ${errorMessage}`);
    }
  }

  public onDispose(): void {
    if (this._floatingElement) {
      this._floatingElement.remove();
      this._floatingElement = null;
    }
  }
}
