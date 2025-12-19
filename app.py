from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3

app = Flask(__name__)
CORS(app)


# ---------- INIT DB ----------
def init_db():
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

init_db()


# ---------- ADD GROCERY ----------
@app.route('/add_grocery', methods=['POST'])
def add_grocery():
    data = request.get_json()

    item = data.get("item")
    amount = float(data.get("amount"))

    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute(
        "INSERT INTO expense (item, amount, category) VALUES (?,?,?)",
        (item, amount, "Grocery")
    )

    conn.commit()
    conn.close()

    return jsonify({"message": "added"}), 200


# ---------- TOTALS ----------
@app.route('/totals', methods=['GET'])
def totals():
    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute("SELECT SUM(amount) FROM expense WHERE category='Grocery'")
    grocery = cur.fetchone()[0] or 0

    conn.close()

    return jsonify({"grocery": grocery})


# ---------- ALL EXPENSES ----------
@app.route('/all', methods=['GET'])
def all_expenses():
    conn = sqlite3.connect("expense.db")
    cur = conn.cursor()

    cur.execute("SELECT item, amount, category FROM expense ORDER BY id DESC")
    rows = cur.fetchall()

    conn.close()

    return jsonify([
        {"item": r[0], "amount": r[1], "category": r[2]} for r in rows
    ])

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

