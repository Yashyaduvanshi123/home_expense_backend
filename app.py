from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3

app = Flask(__name__)
CORS(app)

# ---------- INIT DB ----------
conn = sqlite3.connect("expense.db")
cur = conn.cursor()
cur.execute("""
    CREATE TABLE IF NOT EXISTS expense (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item TEXT,
        amount REAL,
        category TEXT
    )
""")
conn.commit()
conn.close()

# ---------- ADD GROCERY ----------
@app.route('/add_grocery', methods=['POST'])
def add_grocery():
    data = request.get_json()

    item = data.get('item')
    amount = float(data.get('amount'))

    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute("INSERT INTO expense (item, amount, category) VALUES (?,?,?)",
                (item, amount, "Grocery"))

    conn.commit()
    conn.close()

    return jsonify({"message": "added"}), 200


# ---------- TOTALS ----------
@app.route('/totals')
def totals():
    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute("SELECT SUM(amount) FROM expense WHERE category='Grocery'")
    grocery = cur.fetchone()[0] or 0

    cur.execute("SELECT SUM(amount) FROM expense WHERE category='Milk'")
    milk = cur.fetchone()[0] or 0

    conn.close()

    return jsonify({"grocery": grocery, "milk": milk})


# ---------- ALL EXPENSES (NOW RETURNS ID TOO) ----------
@app.route('/all')
def all_expenses():
    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute("SELECT id, item, amount, category FROM expense ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()

    expenses = []
    for r in rows:
        expenses.append({
            "id": r[0],
            "item": r[1],
            "amount": r[2],
            "category": r[3]
        })

    return jsonify(expenses)


# ---------- DELETE EXPENSE ----------
@app.route('/delete/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute("DELETE FROM expense WHERE id=?", (item_id,))
    conn.commit()
    conn.close()

    return jsonify({"message": "deleted"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
