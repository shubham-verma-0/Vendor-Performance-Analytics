import sqlite3
import pandas as pd
import logging
from ingestion_db import ingest_db

logging.basicConfig(
    filename="logs/get_vendor_summary.log",
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s",
    filemode="a"
)

def create_vendor_summary(conn):
    """
    This function merges different tables to generate the overall vendor summary.
    """

    vendor_sales_summary = pd.read_sql_query("""
    
    WITH FreightSummary AS (
        SELECT
            vendornumber,
            SUM(freight) AS freightcost
        FROM vendor_invoice
        GROUP BY vendornumber
    ),

    PurchaseSummary AS (
        SELECT
            p.vendornumber,
            p.vendorname,
            p.brand,
            p.description,
            p.purchaseprice,
            pp.price AS actualprice,
            pp.volume,
            SUM(p.quantity) AS totalpurchasequantity,
            SUM(p.dollars) AS totalpurchasedollars
        FROM purchases p
        JOIN purchase_prices pp
            ON p.brand = pp.brand
        WHERE p.purchaseprice > 0
        GROUP BY
            p.vendornumber,
            p.vendorname,
            p.brand,
            p.description,
            p.purchaseprice,
            pp.price,
            pp.volume
    ),

    SalesSummary AS (
        SELECT
            vendorno,
            brand,
            SUM(salesquantity) AS totalsalesquantity,
            SUM(salesdollars) AS totalsalesdollars,
            SUM(salesprice) AS totalsalesprice,
            SUM(excisetax) AS totalexcisetax
        FROM sales
        GROUP BY
            vendorno,
            brand
    )

    SELECT
        ps.vendornumber,
        ps.vendorname,
        ps.brand,
        ps.description,
        ps.purchaseprice,
        ps.actualprice,
        ps.volume,
        ps.totalpurchasequantity,
        ps.totalpurchasedollars,
        ss.totalsalesquantity,
        ss.totalsalesdollars,
        ss.totalsalesprice,
        ss.totalexcisetax,
        fs.freightcost

    FROM PurchaseSummary ps

    LEFT JOIN SalesSummary ss
        ON ps.vendornumber = ss.vendorno
       AND ps.brand = ss.brand

    LEFT JOIN FreightSummary fs
        ON ps.vendornumber = fs.vendornumber

    ORDER BY ps.totalpurchasedollars DESC;

    """, conn)

    return vendor_sales_summary

def clean_data(df):
    """
    This function will clean the data.
    """

    # Changing datatype to float
    df['volume'] = df['volume'].astype(float)

    # Filling missing values with 0
    df.fillna(0, inplace=True)

    # Removing spaces from categorical columns
    df['vendorname'] = df['vendorname'].str.strip()
    df['description'] = df['description'].str.strip()

    # Creating new columns for better analysis
    df['GrossProfit'] = (
        df['totalsalesdollars'] - df['totalpurchasedollars']
    )

    df['ProfitMargin'] = (
        df['GrossProfit'] / df['totalsalesdollars']
    ) * 100

    df['StockTurnover'] = (
        df['totalsalesquantity'] / df['totalpurchasequantity']
    )

    df['SalesToPurchaseRatio'] = (
        df['totalsalesdollars'] / df['totalpurchasedollars']
    )

    return df
    
if __name__ == "__main__":

    # Creating database connection
    conn = sqlite3.connect("inventory.db")

    logging.info("Creating Vendor Summary Table.....")
    summary_df = create_vendor_summary(conn)
    logging.info(summary_df.head())

    logging.info("Cleaning Data.......")
    clean_df = clean_data(summary_df)
    logging.info(clean_df.head())

    logging.info("Ingesting data......")
    ingest_db(clean_df, "vendor_sales_summary", conn)

    logging.info("Completed")