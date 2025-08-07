import * as jwt from "jsonwebtoken";
import { JwtPayload } from "../types/auth.types";

export class JwtUtil {
  private accessTokenSecret: jwt.Secret;
  private accessTokenExpiry: string;

  constructor() {
    this.accessTokenSecret =
      process.env.JWT_ACCESS_SECRET || "your-access-secret";
    this.accessTokenExpiry = process.env.JWT_ACCESS_EXPIRY || "15h";
    if (!this.accessTokenSecret) {
      throw new Error("JWT_ACCESS_SECRET is not defined");
    }
  }

  generateAccessToken(payload: JwtPayload): string {
    const options: jwt.SignOptions = {
      issuer: "boxin1",
    };
    return jwt.sign(payload, this.accessTokenSecret, options);
  }

  verifyAccessToken(token: string): JwtPayload {
    try {
      return jwt.verify(token, this.accessTokenSecret) as JwtPayload;
    } catch (error) {
      throw new Error(`Invalid token`);
    }
  }
}
