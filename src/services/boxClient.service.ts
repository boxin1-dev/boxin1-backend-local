// src/services/boxClient.service.ts
import axios from "axios";
import os from "os";

export interface IPInfoData {
  ip: string;
  city: string;
  region: string;
  country: string;
  loc: string;
  org: string;
  timezone: string;
  readme?: string;
}

export interface BoxClientInfoData extends IPInfoData {
  macAddress: string;
}

/**
 * 🎯 Service orienté objet pour gérer l'envoi des infos Box au cloud.
 */
export class BoxClientService {
  private cloudApiUrl: string;

  constructor(cloudApiUrl?: string) {
    this.cloudApiUrl =
      cloudApiUrl ||
      process.env.BOXIN1_CLOUD_API ||
      "http://46.202.134.188:4000/api/box-client-infos";
  }

  /**
   * 🔍 Récupère l'adresse MAC locale
   */
  private getMacAddress(): string | undefined {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
      const networkInterface = interfaces[name];
      if (networkInterface) {
        for (const net of networkInterface) {
          if (!net.internal && net.mac && net.mac !== "00:00:00:00:00:00") {
            return net.mac;
          }
        }
      }
    }
  }

  /**
   * 🌍 Récupère les informations IP publiques
   */
  private async getIPInfo(): Promise<IPInfoData> {
    try {
      const response = await axios.get<IPInfoData>("https://ipinfo.io");
      return response.data;
    } catch (error) {
      console.error("❌ Erreur lors de la récupération des infos IP:", error);
      throw new Error("Impossible de récupérer les informations IP");
    }
  }

  /**
   * ☁️ Envoie les données combinées (IP + MAC) vers le cloud
   */
  private async sendDataToCloud(data: BoxClientInfoData): Promise<void> {
    try {
      const response = await axios.post(this.cloudApiUrl, data, {
        headers: { "Content-Type": "application/json" },
      });
      console.log("✅ Données envoyées avec succès:", response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        console.error(
          "❌ Erreur d'envoi:",
          error.response?.data || error.message
        );
      } else {
        console.error("❌ Erreur inattendue:", error);
      }
      throw error;
    }
  }

  /**
   * 🚀 Méthode publique principale : récupère IP + MAC et envoie au cloud
   */
  async connectToCloud(): Promise<void> {
    console.log("🧠 Démarrage de l’enregistrement du client...");

    const mac = this.getMacAddress() || "Indisponible";
    console.log("💻 Adresse MAC:", mac);

    const ipInfo = await this.getIPInfo();
    console.log("🌍 Infos IP:", ipInfo);

    const boxData: BoxClientInfoData = { ...ipInfo, macAddress: mac };

    await this.sendDataToCloud(boxData);

    console.log("✅ Connexion de la box vers le cloud avec succès !");
  }
}
