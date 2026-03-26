import pandas as pd
import os

EXCEL_PATH = r"C:\Users\DELL.COM\Desktop\Darey\headcount\latest_heascount_from_FA_UPDATED-2.xlsx"
OUTPUT_DIR = r"C:\Users\DELL.COM\Desktop\Darey\headcount\assets"
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "residents_seed.csv")

OUTPUT_COLUMNS = [
    "S/N", "House Address", "Zone/Block", "Total Flats in compound",
    "House Type", "Unit/Flat", "Occupied?", "Record Status",
    "# Households", "Monthly Due", "Payment Status", "Last Payment Date",
    "Adults", "Children", "Total Headcount", "Main Contact Name",
    "Contact Role (Owner/Tenant/Caretaker)", "Phone Number",
    "WhatsApp Number", "Email", "App Registered?",
    "Phone Type (Android/iPhone)", "Notes/Issues", "Visit Date",
    "Visited By", "Data Verified?", "Follow-up Needed?", "Follow-up Date",
    "Data Source", "Verification Status", "First Verified Date", "Last Updated By",
]

HOUSE_TYPE_MAP = {
    "mini flat": "Mini flat", "mini-flat": "Mini flat",
    "1 bedrooms": "1 bedroom", "1 bedroom": "1 bedroom",
    "2 bedrooms": "2 bedroom", "2-bedroom": "2 bedroom", "2 bedroom": "2 bedroom",
    "3 bedrooms": "3 bedroom", "3-bedroom": "3 bedroom", "3 bedroom": "3 bedroom",
    "4 bedrooms": "4 bedroom", "4 bedroom": "4 bedroom",
    "5 bedrooms": "5 bedroom", "5 bedroom": "5 bedroom",
    "bungalow": "Bungalow", "duplex": "Duplex",
}

CONTACT_ROLE_MAP = {
    "owner": "Owner",
    "tenant": "Tenant",
    "caretaker": "Caretaker",
    "care taker": "Caretaker",
}

def normalise_house_type(value):
    if pd.isna(value) or str(value).strip() == '': return ''
    return HOUSE_TYPE_MAP.get(str(value).strip().lower(), str(value).strip())

def safe_int(v):
    try: return int(float(str(v).strip()))
    except: return 0

def clean_val(v):
    if pd.isna(v): return ''
    s = str(v).strip()
    if s.lower() in ('nan', 'none', 'nat'): return ''
    # Remove embedded newlines/carriage returns to keep CSV clean
    s = s.replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ')
    return s

def normalize_yes_no(v, fallback='No'):
    s = clean_val(v).lower()
    if s in ('yes', 'y', 'occupied', 'true'):
        return 'Yes'
    if s in ('no', 'n', 'vacant', 'false'):
        return 'No'
    return fallback

def normalize_contact_role(v):
    s = clean_val(v)
    if not s:
        return ''
    return CONTACT_ROLE_MAP.get(s.lower(), s)

def main():
    print('Reading:', EXCEL_PATH)
    df = pd.read_excel(EXCEL_PATH, sheet_name='Headcount', engine='openpyxl', dtype=str)
    print('  Raw shape:', df.shape)
    df.columns = [c.strip() for c in df.columns]
    for col in OUTPUT_COLUMNS:
        if col not in df.columns:
            print('  WARNING: col not in Excel:', col)
            df[col] = ''
    df = df[OUTPUT_COLUMNS].copy()

    # Fill cascaded compound fields for blank continuation rows
    df['House Address'] = df['House Address'].ffill()
    df['Zone/Block'] = df['Zone/Block'].ffill()
    df['Total Flats in compound'] = df['Total Flats in compound'].ffill()

    df['House Type'] = df['House Type'].apply(normalise_house_type)
    df['Contact Role (Owner/Tenant/Caretaker)'] = df['Contact Role (Owner/Tenant/Caretaker)'].apply(normalize_contact_role)
    df['Occupied?'] = df['Occupied?'].apply(lambda v: normalize_yes_no(v, fallback='No'))
    df['Record Status'] = df['Occupied?'].apply(lambda v: 'Occupied' if v == 'Yes' else 'Vacant')
    df['App Registered?'] = df['App Registered?'].apply(lambda v: normalize_yes_no(v, fallback='No'))
    df['Data Verified?'] = df['Data Verified?'].apply(lambda v: normalize_yes_no(v, fallback='No'))
    df['Follow-up Needed?'] = df['Follow-up Needed?'].apply(lambda v: normalize_yes_no(v, fallback='No'))
    for col in ['Adults', 'Children']:
        df[col] = df[col].apply(lambda v: '0' if (pd.isna(v) or str(v).strip().lower() in ('', 'nan', 'none')) else str(v).strip())
    df['Total Headcount'] = df.apply(lambda row: str(safe_int(row['Adults']) + safe_int(row['Children'])), axis=1)
    df['Data Source'] = df['Data Source'].apply(lambda v: 'Preloaded' if (pd.isna(v) or str(v).strip().lower() in ('', 'nan', 'none')) else str(v).strip())
    df['Verification Status'] = df['Verification Status'].apply(lambda v: 'Unverified' if (pd.isna(v) or str(v).strip().lower() in ('', 'nan', 'none')) else str(v).strip())
    # Clean all cells (strips NaN, embedded newlines)
    for col in df.columns:
        df[col] = df[col].apply(clean_val)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    df.to_csv(OUTPUT_PATH, index=False, encoding='utf-8', lineterminator='\n')
    print('  Written', len(df), 'data rows to:', OUTPUT_PATH)
    # Verify using csv module (handles quoted fields correctly)
    import csv
    with open(OUTPUT_PATH, encoding='utf-8', newline='') as f:
        reader = csv.reader(f)
        rows = list(reader)
    total = len(rows)
    col_count = len(rows[0])
    print('  Total rows (csv.reader, header + data):', total)
    print('  Column count:', col_count)
    print('  Header:', ','.join(rows[0])[:120])
    if total == 423: print('  PASS: 423 rows (1 header + 422 data rows)')
    else: print('  WARNING: expected 423, got', total)
    if col_count == 32: print('  PASS: 32 columns')
    else: print('  WARNING: expected 32 cols, got', col_count)

if __name__ == '__main__':
    main()
