import qs from "qs";
import secrets from "../../../secrets/myanimelist";
import { constants } from "../../util";
import { http, RequesterOptions, Store } from "../../api";
import { Auth, AuthClient, TokenInfo } from "./auth";
import Logger from "../../logger";

export interface MyAnimeListOptions {
    client: AuthClient;
}

export interface UserInfoEntity {
    id: number;
    name: string;
    location: string;
    joined_at: string;
}

export interface AnimeListEntity {
    data: {
        node: {
            id: number;
            title: string;
            main_picture: {
                medium: string;
                large: string;
            };
        };
        list_status: {
            status: string;
            score: number;
            num_episodes_watched: number;
            is_rewatching: boolean;
            updated_at: string;
        };
    }[];
    paging: {
        next: string;
    };
}

export interface AnimeEntity {
    id: number;
    title: string;
    my_list_status: {
        status: string;
        score: number;
        num_episodes_watched: number;
        is_rewatching: boolean;
        updated_at: string;
    };
    num_episodes: number;
}

export interface AnimeUpdateBody {
    status: AnimeStatusType;
    score: number;
    num_watched_episodes: number;
}

export interface AnimeUpdateResultEntity {
    status: string;
    score: number;
    num_episodes_watched: number;
    is_rewatching: boolean;
    updated_at: string;
    priority: number;
    num_times_rewatched: number;
    rewatch_value: number;
}

export const AnimeStatus = [
    "watching",
    "completed",
    "on_hold",
    "dropped",
    "plan_to_watch",
] as const;
export type AnimeStatusType = typeof AnimeStatus[number];

export class MyAnimeListManager {
    webURL = "https://myanimelist.net";
    baseURL = "https://api.myanimelist.net/v2";

    auth: Auth;

    constructor() {
        this.auth = new Auth({
            id: secrets.client_id,
            redirect: secrets.callback,
        });
    }

    async initialize() {
        const store = await Store.getClient();
        const token: TokenInfo | null = await store.get(
            constants.storeKeys.myAnimeListToken
        );

        if (token) {
            this.auth.setToken(token);
            if (!this.auth.isValidToken()) {
                const res = await this.auth.refreshToken();
                if (!res.success && res.error?.includes("401")) {
                    Logger.emit("warn", "MyAnimeList session has expired");
                    await this.removeToken();
                }
            }
        }
    }

    isLoggedIn() {
        return this.auth.isValidToken();
    }

    async authenticate(code: string) {
        const res = await this.auth.getToken(code);
        if (this.auth.token) await this.storeToken();
        return res;
    }

    async storeToken() {
        if (!this.auth.token) return false;

        const store = await Store.getClient();
        await store.set(constants.storeKeys.myAnimeListToken, this.auth.token);
    }

    async removeToken() {
        const store = await Store.getClient();
        await store.set(constants.storeKeys.myAnimeListToken, null);
    }

    async userInfo() {
        const res = await this.request("get", "/users/@me");
        return res && <UserInfoEntity>JSON.parse(res);
    }

    async animelist(status?: AnimeStatusType, page: number = 0) {
        const perpage = 100;
        const res = await this.request(
            "get",
            `/users/@me/animelist?fields=list_status&sort=list_updated_at&limit=${perpage}&offset=${
                perpage * page
            }${status ? `&status=${status}` : ""}`
        );
        return res && <AnimeListEntity>JSON.parse(res);
    }

    async getAnime(id: string) {
        const res = await this.request(
            "get",
            `/anime/${id}?fields=id,title,my_list_status,num_episodes`
        );
        return res && <AnimeEntity>JSON.parse(res);
    }

    async updateAnime(id: string, body: Partial<AnimeUpdateBody>) {
        const res = await this.request(
            "put",
            `/anime/${id}/my_list_status`,
            body
        );
        return res && <AnimeUpdateResultEntity>JSON.parse(res);
    }

    async searchAnime(title: string) {
        const res = await this.request("get", `/anime?q=${title}&limit=10`);
        return res && <AnimeListEntity>JSON.parse(res);
    }

    request(type: "get", url: string): Promise<false | string>;
    request(
        type: "post" | "patch" | "put",
        url: string,
        body: any
    ): Promise<false | string>;
    async request(
        type: "get" | "post" | "patch" | "put",
        url: string,
        body?: any
    ) {
        if (!this.auth.token) return false;

        url = encodeURI(`${this.baseURL}${url}`);
        const options: RequesterOptions = {
            headers: {
                Authorization: `${this.auth.token.token_type} ${this.auth.token.access_token}`,
            },
            responseType: "text",
        };
        if (body) {
            options.headers["Content-Type"] =
                "application/x-www-form-urlencoded";
            body = qs.stringify(body);
        }

        const client = await http.getClient();
        let res: string;
        try {
            switch (type) {
                case "get":
                    res = await client[type](url, options);
                    break;

                case "post":
                case "patch":
                case "put":
                    res = await client[type](url, body, options);
                    break;
            }
        } catch (err) {
            if (
                typeof err?.message === "string" &&
                (<string>err.message).includes("401")
            ) {
                this.auth.refreshToken();
                // @ts-ignore
                return this.request(type, url, body);
            }

            throw err;
        }

        return res;
    }

    async logout() {
        this.auth.setToken(null);
        await this.removeToken();
    }
}

export default new MyAnimeListManager();