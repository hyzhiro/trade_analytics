# trade_analytics

A lightweight trade analytics application for importing trade history, evaluating performance, and visualizing trading patterns.

## Features

- Import trade history (CSV from MT4/MT5 or other brokers)
- Calculate performance metrics:
  - Win rate
  - Average risk/reward ratio
  - Profit factor
  - Max drawdown
  - Daily/weekly/monthly P&L
- Visualize trade results with interactive charts
- Filter and analyze trades by symbol, direction, session, and more
- Extensible design for strategy development and future add-ons

## Requirements

- Node.js (LTS recommended)
- npm or yarn
- Modern web browser

## Getting Started

Clone the repository:

````bash
git clone https://github.com/hyzhiro/trade_analytics.git
cd trade_analytics
````

Install dependencies:

````bash
npm install
````

Run the development server:

````bash
npm run dev
````

Build for production:

````bash
npm run build
````

## Project Structure

````text
trade_analytics/
  ├── src/
  │   ├── components/
  │   ├── pages/
  │   ├── utils/
  │   └── styles/
  ├── public/
  ├── package.json
  ├── README.md
  └── LICENSE
````

## Roadmap

- Cloud sync for historical trade data  
- Advanced statistical modules  
- Backtest result importer  
- API integration for real-time performance tracking  

## License

MIT License  
See the [LICENSE](./LICENSE) file for details.
