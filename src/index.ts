// src/app.ts
import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import helmet from "helmet";
import swaggerJsdoc from "swagger-jsdoc";
import swaggerUi from "swagger-ui-express";
import path from "path";
import authRoutes from "./routes/auth.routes";
import deviceRoutes from "./routes/device.routes";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configuration Swagger OPTIMISÉE
const swaggerOptions = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Boxin1 API",
      version: "1.0.0",
      description: "API pour la gestion des appareils SmartBox",
      contact: {
        name: "API Support",
        email: "support@boxin1.com"
      }
    },
    servers: [
      {
        url: `http://localhost:${PORT}`,
        description: "Development server",
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT",
        },
      },
    },
  },
  // Chemins ABSOLUS pour plus de fiabilité
  apis: [
    path.resolve(__dirname, "routes/*.ts"),
    path.resolve(__dirname, "routes/*.js"),
    "./src/routes/*.ts",
    "./dist/routes/*.js",
  ],
};

console.log('🔧 Configuration Swagger:');
console.log('Fichiers analysés:', swaggerOptions.apis);

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Vérification des routes détectées
console.log('📊 Routes Swagger détectées:');


// Middlewares
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || "http://localhost:5173",
  credentials: true,
}));

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Swagger UI avec options améliorées
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  explorer: true,
  customSiteTitle: "Boxin1 API Documentation",
  swaggerOptions: {
    persistAuthorization: true,
    displayRequestDuration: true,
  },
}));

// Route pour obtenir la spec Swagger en JSON
app.get("/api-docs.json", (req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.send(swaggerSpec);
});

// Montage des routes
app.use("/api/auth", authRoutes);
app.use("/api/devices", deviceRoutes);

// Health check
app.get("/health", (req, res) => {
  res.json({
    success: true,
    message: "Server is running",
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || "development"
  });
});

// Démarrage du serveur
app.listen(PORT, () => {
  console.log(`🚀 Serveur démarré sur le port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`📚 Swagger UI: http://localhost:${PORT}/api-docs`);
  console.log(`📖 Swagger JSON: http://localhost:${PORT}/api-docs.json`);
  console.log(`🏥 Health: http://localhost:${PORT}/health`);
});

export default app;