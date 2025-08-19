import {
  UsersApi,
  Passkey,
  MeRsp,
  AuthApi,
  ProcessResponse,
} from './frontendapi';
import {
  Configuration,
  PasskeyAppendStartRsp,
  PasskeysApi,
} from './backendapi';
import axios, { AxiosError } from 'axios';
import { CorbadoError } from './exceptions';
import { RequestMetadata } from './types';
import { BASE_PATH } from './backendapi/base';

export type User = {
  email: string;
  name: string;
  orig: string;
  sub: string;
  exp: number;
};

export class CorbadoService {
  #usersApi: UsersApi;
  #userApi: UsersApi;
  #passkeyApi: PasskeysApi;
  #authApi: AuthApi;

  constructor(basePath: string, projectId: string, apiSecret: string) {
    const axiosInstance = axios.create({
      timeout: 10000,
      withCredentials: true,
    });

    // We transform AxiosErrors into CorbadoErrors using axios interceptors.
    axiosInstance.interceptors.response.use(
      (response) => {
        return response;
      },
      (error: AxiosError) => {
        const e = CorbadoError.fromAxiosError(error);
        return Promise.reject(e);
      }
    );

    this.#usersApi = new UsersApi(undefined, basePath, axiosInstance);
    this.#authApi = new AuthApi(undefined, basePath, axiosInstance);

    const backendApiConfig = new Configuration({
      username: projectId,
      password: apiSecret,
    });
    this.#userApi = new UsersApi(backendApiConfig, BASE_PATH, axiosInstance);
    this.#passkeyApi = new PasskeysApi(
      backendApiConfig,
      BASE_PATH,
      axiosInstance
    );
  }

  async startSignUpWithPasskey(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    try {
      const res = await this.#authApi.signupInit(
        {
          fullName: email,
          identifiers: [{ type: 'email', identifier: email }],
        },
        metadata.toRawAxiosRequestConfig()
      );

      return res.data;
    } catch (e) {
      console.log(e);
      throw e;
    }
  }

  async finishSignUpWithPasskey(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const res = await this.#authApi.passkeyAppendFinish(
      { signedChallenge: signedChallenge },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async startPasskeyAppend(
    username: string,
    fullname: string,
    metadata: RequestMetadata
  ): Promise<PasskeyAppendStartRsp> {
    const res = await this.#passkeyApi.passkeyAppendStart(
      {
        userID: '',
        processID: '',
        username: username,
        clientInformation: {
          remoteAddress: metadata.remoteAddress,
          userAgent: metadata.userAgent,
          userVerifyingPlatformAuthenticatorAvailable: false,
          conditionalMediationAvailable: false,
          parsedDeviceInfo: {
            browserName: '',
            browserVersion: '',
            osName: '',
            osVersion: '',
          },
        },
        passkeyIntelFlags: {
          forcePasskeyAppend: false,
        },
      },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async finishPasskeyAppend(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const res = await this.#authApi.passkeyAppendFinish(
      { signedChallenge: signedChallenge },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async startLoginWithPasskey(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const res = await this.#authApi.loginInit(
      {
        identifierValue: email,
        isPhone: false,
      },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async finishLoginWithPasskey(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const res = await this.#authApi.passkeyLoginFinish(
      { signedChallenge: signedChallenge },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async startLoginWithEmailOTP(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const res = await this.#authApi.identifierVerifyStart(
      {
        identifierType: 'email',
        verificationType: 'email-otp',
      },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async finishLoginWithEmailOTP(
    code: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const res = await this.#authApi.identifierVerifyFinish(
      {
        code: code,
        identifierType: 'email',
        verificationType: 'email-otp',
        isNewDevice: false,
      },
      metadata.toRawAxiosRequestConfig()
    );

    return res.data;
  }

  async deleteUser(metadata: RequestMetadata): Promise<void> {
    await this.#userApi.currentUserDelete(metadata.toRawAxiosRequestConfig());
  }

  async getFullUser(metadata: RequestMetadata): Promise<MeRsp> {
    const res = await this.#userApi.currentUserGet(
      metadata.toRawAxiosRequestConfig()
    );
    return res.data;
  }

  async getPasskeys(metadata: RequestMetadata): Promise<Array<Passkey>> {
    const res = await this.#userApi.currentUserPasskeyGet(
      metadata.toRawAxiosRequestConfig()
    );
    return res.data.passkeys;
  }

  async deletePasskey(
    passkeyId: string,
    metadata: RequestMetadata
  ): Promise<void> {
    await this.#userApi.currentUserPasskeyDelete(
      passkeyId,
      metadata.toRawAxiosRequestConfig()
    );
  }

  async updateUserWithFullName(
    fullName: string,
    metadata: RequestMetadata
  ): Promise<void> {
    await this.#userApi.currentUserUpdate(
      { fullName: fullName },
      metadata.toRawAxiosRequestConfig()
    );
  }
}
