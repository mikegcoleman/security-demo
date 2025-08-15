const express = require('express');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const session = require('express-session');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { MongoClient, ObjectId } = require('mongodb');
const path = require('path');
const _ = require('lodash');

const app = express();
const PORT = process.env.PORT || 8080;

// mongodb connection
const MONGO_DB = process.env.MONGO_DB || "appdb";
const MONGO_URI = process.env.MONGO_URI

if (MONGO_URI === "") {
    console.error("Database connection string must be provided");
    process.exit(1);
}

let db;
let client;

// connect to mongodb
async function connectDB() {
    try {
        client = new MongoClient(MONGO_URI, { 
            useNewUrlParser: true, 
            useUnifiedTopology: true,
            serverSelectionTimeoutMS: 5000
        });
        await client.connect();
        db = client.db(MONGO_DB);
        console.log(`Connected to MongoDB at ${MONGO_URI} <-- well lookee there`);
        
        // Create initial collections if needed
        await ensureCollectionExists('users');
        await ensureCollectionExists('todos');
        
        // Create default admin user
        const adminExists = await db.collection('users').findOne({ username: 'admin' });
        if (!adminExists) {
            const hashedPassword = await bcrypt.hash('admin123', 10);
            await db.collection('users').insertOne({
                username: 'admin',
                password: hashedPassword,
                isAdmin: true,
                created: new Date()
            });
            console.log('Default admin user created');
        }
        
    } catch (error) {
        console.error('MongoDB connection error:', error);
        process.exit(1);
    }
}

// Middleware setup
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));
app.use(cookieParser());

app.use(session({
    secret: 'weak-secret-key',
    resave: false,
    saveUninitialized: true,
    cookie: { secure: false, httpOnly: false }
}));

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

const JWT_SECRET = 'super-secret-jwt-key';

// authentication middleware
function authenticateToken(req, res, next) {
    const token = req.query.token || req.headers['authorization']?.split(' ')[1] || req.cookies.token;
    
    if (!token) {
        return res.redirect('/login');
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.redirect('/login');
        }
        req.user = user;
        next();
    });
}


// home page - redirect to todos
app.get('/', (req, res) => {
    res.redirect('/todos');
});

// Login page
app.get('/login', (req, res) => {
    res.render('login');
});

// Login Handler
app.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;
    
        const user = await db.collection('users').findOne({ username: username });
        
        if (!user || !await bcrypt.compare(password, user.password)) {
            return res.render('login', { error: 'Invalid credentials' });
        }
        
        const token = jwt.sign({ 
            id: user._id, 
            username: user.username,
            isAdmin: user.isAdmin 
        }, JWT_SECRET, { expiresIn: '24h' });
    
        res.cookie('token', token, { httpOnly: false, secure: false });
        res.redirect('/todos');
        
    } catch (error) {
        console.error('Login error:', error);
        res.render('login', { error: 'Login failed' });
    }
});

// reg page
app.get('/register', (req, res) => {
    res.render('register');
});

// registration
app.post('/register', async (req, res) => {
    try {
        const { username, password, email } = req.body;
        
        const existingUser = await db.collection('users').findOne({ username: username });
        if (existingUser) {
            return res.render('register', { error: 'Username already exists' });
        }
        
        const hashedPassword = await bcrypt.hash(password, 10);
        await db.collection('users').insertOne({
            username: username,
            password: hashedPassword,
            email: email, 
            isAdmin: false,
            created: new Date()
        });
        
        res.redirect('/login');
        
    } catch (error) {
        console.error('Registration error:', error);
        res.render('register', { error: 'Registration failed' });
    }
});

// Todos page
app.get('/todos', authenticateToken, async (req, res) => {
    try {
        const todos = await db.collection('todos').find({ userId: req.user.id }).toArray();
        res.render('todos', { user: req.user, todos: todos });
    } catch (error) {
        console.error('Error fetching todos:', error);
        res.render('todos', { user: req.user, todos: [], error: 'Failed to load todos' });
    }
});

// Add todo
app.post('/todos', authenticateToken, async (req, res) => {
    try {
        const { title, description } = req.body;
        

        const todo = {
            title: title,
            description: description,
            completed: false,
            userId: req.user.id,
            username: req.user.username,
            created: new Date()
        };
        
        await db.collection('todos').insertOne(todo);
        res.redirect('/todos');
        
    } catch (error) {
        console.error('Error adding todo:', error);
        res.redirect('/todos');
    }
});

// Update todo
app.post('/todos/:id/toggle', authenticateToken, async (req, res) => {
    try {
        const todoId = req.params.id;
        const todo = await db.collection('todos').findOne({ _id: ObjectId(todoId), userId: req.user.id });
        
        if (todo) {
            await db.collection('todos').updateOne(
                { _id: ObjectId(todoId), userId: req.user.id },
                { $set: { completed: !todo.completed } }
            );
        }
        
        res.redirect('/todos');
    } catch (error) {
        console.error('Error updating todo:', error);
        res.redirect('/todos');
    }
});

// delete todo 
app.post('/todos/:id/delete', authenticateToken, async (req, res) => {
    try {
        await db.collection('todos').deleteOne({ _id: ObjectId(req.params.id), userId: req.user.id });
        res.redirect('/todos');
    } catch (error) {
        console.error('Error deleting todo:', error);
        res.redirect('/todos');
    }
});

// admin console
app.get('/admin', authenticateToken, async (req, res) => {
    if (!req.user.isAdmin) {
        return res.status(403).send('Access denied');
    }
    
    try {
        const users = await db.collection('users').find({}).toArray();
        const todos = await db.collection('todos').find({}).toArray();
        res.render('admin', { users: users, todos: todos });
    } catch (error) {
        console.error('Admin error:', error);
        res.status(500).send('Internal server error');
    }
});


app.get('/api/debug', (req, res) => {
    res.json({
        environment: process.env,
        mongodb_uri: MONGO_URI,
        jwt_secret: JWT_SECRET,
        session_secret: 'weak-secret-key'
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', mongodb: db ? 'connected' : 'disconnected' });
});

// Logout
app.get('/logout', (req, res) => {
    res.clearCookie('token');
    res.redirect('/login');
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).send('Something broke!');
});


// utility functions
async function ensureCollectionExists(name) {
    const collections = await db.listCollections({ name }).toArray();
    if (collections.length === 0) {
        await db.createCollection(name);
        console.log(`Created collection: ${name}`);
    } else {
        console.log(`Collection already exists: ${name}`);
    }
}
// start server
connectDB().then(() => {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`TaskFlow Todo App running on port ${PORT}`);
    });
});

// graceful shutdown
process.on('SIGTERM', async () => {
    console.log('shutting down gracefully');
    if (client) {
        await client.close();
    }
    process.exit(0);
});