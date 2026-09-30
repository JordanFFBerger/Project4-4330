const express = require("express");
const sqlite3 = require("sqlite3").verbose();
const bcrypt = require("bcryptjs");
const cors = require("cors");

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

const db = new sqlite3.Database("./users.db", (err) => {
    if (err) {
        console.error(err.message);
    } else {
        console.log("Connected to SQLite database");
    }
});

db.run(`
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
    )
`);

app.get("/", (req, res) => {
    res.json({
        message: "Pokemon App Server is running!"
    });
});

app.post("/register", async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({
            success: false,
            message: "Username and password are required"
        });
    }

    try {
        const hashedPassword = await bcrypt.hash(password, 10);

        db.run(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            [username, hashedPassword],
            function (err) {
                if (err) {
                    if (err.message.includes("UNIQUE")) {
                        return res.status(409).json({
                            success: false,
                            message: "Username already exists"
                        });
                    }

                    return res.status(500).json({
                        success: false,
                        message: "Database error"
                    });
                }

                res.status(201).json({
                    success: true,
                    message: "Account created successfully",
                    userId: this.lastID
                });
            }
        );
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server error"
        });
    }
});

app.post("/login", (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({
            success: false,
            message: "Username and password are required"
        });
    }

    db.get(
        "SELECT * FROM users WHERE username = ?",
        [username],
        async (err, user) => {
            if (err) {
                return res.status(500).json({
                    success: false,
                    message: "Database error"
                });
            }

            if (!user) {
                return res.status(401).json({
                    success: false,
                    message: "Invalid username or password"
                });
            }

            const passwordMatches = await bcrypt.compare(
                password,
                user.password
            );

            if (!passwordMatches) {
                return res.status(401).json({
                    success: false,
                    message: "Invalid username or password"
                });
            }

            res.json({
                success: true,
                message: "Login successful",
                user: {
                    id: user.id,
                    username: user.username
                }
            });
        }
    );
});

app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running at http://localhost:${PORT}`);
});