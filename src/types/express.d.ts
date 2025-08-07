// src/types/express.d.ts
import { JwtPayload } from "./auth.types";
declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}
