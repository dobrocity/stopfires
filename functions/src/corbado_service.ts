import {
  UsersApi,
  Passkey,
  MeRsp,
  AuthApi,
  ProcessResponse,
  LoginIdentifierType,
  VerificationMethod,
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

// ============================================================================
// TYPES AND INTERFACES
// ============================================================================

export type User = {
  email: string;
  name: string;
  orig: string;
  sub: string;
  exp: number;
};

export interface AuthFlowData {
  email: string;
  fullName?: string;
  signedChallenge?: string;
  code?: string;
}

export interface PasskeyFlowData {
  username: string;
  fullName: string;
  signedChallenge?: string;
}

// ============================================================================
// CORBADO SERVICE - DATA FLOW ORGANIZED
// ============================================================================

export class CorbadoService {
  // ========================================================================
  // PRIVATE PROPERTIES - API CLIENT INSTANCES
  // ========================================================================
  #usersApi!: UsersApi;
  #userApi!: UsersApi;
  #passkeyApi!: PasskeysApi;
  #authApi!: AuthApi;

  // ========================================================================
  // PRIVATE PROPERTIES - PROCESS STATE MANAGEMENT
  // ========================================================================
  #processID?: string;
  #processExpiresAt?: Date;

  // ========================================================================
  // CONSTRUCTOR - INITIALIZATION FLOW
  // ========================================================================
  constructor(basePath: string, projectId: string, apiSecret: string) {
    const axiosInstance = this.#createAxiosInstance();
    this.#initializeApiClients(basePath, projectId, apiSecret, axiosInstance);
  }

  // ========================================================================
  // PRIVATE INITIALIZATION METHODS
  // ========================================================================
  #createAxiosInstance() {
    const axiosInstance = axios.create({
      timeout: 10000,
      withCredentials: true,
    });

    // Error handling interceptor - transforms AxiosErrors into CorbadoErrors
    axiosInstance.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        const e = CorbadoError.fromAxiosError(error);
        return Promise.reject(e);
      }
    );

    return axiosInstance;
  }

  #initializeApiClients(
    basePath: string,
    projectId: string,
    apiSecret: string,
    axiosInstance: any
  ) {
    // Frontend API clients (for user-facing operations)
    this.#usersApi = new UsersApi(undefined, basePath, axiosInstance);
    this.#authApi = new AuthApi(undefined, basePath, axiosInstance);

    // Backend API clients (for server-side operations)
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

  // ========================================================================
  // AUTHENTICATION FLOW - PROCESS MANAGEMENT
  // ========================================================================
  async initAuthProcess(metadata: RequestMetadata): Promise<ProcessResponse> {
    const clientInfo = await this.#buildClientInformation(metadata);
    const processInitReq = {
      clientInformation: clientInfo,
    };

    const response = await this.#authApi.processInit(
      processInitReq,
      metadata.toRawAxiosRequestConfig()
    );

    if (response.data?.newClientEnvHandle) {
      // Store the new client environment handle if provided
      // This would typically be stored in a secure storage service
      console.log(
        'New client env handle received:',
        response.data.newClientEnvHandle
      );
    }

    this.#setProcessState(response.data?.token, response.data?.expiresAt);

    return response.data?.processResponse;
  }

  async completeAuthProcess(
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const response = await this.#authApi.processComplete(
      metadata.toRawAxiosRequestConfig()
    );
    return response.data;
  }

  async resetAuthProcess(metadata: RequestMetadata): Promise<ProcessResponse> {
    const response = await this.#authApi.processReset(
      metadata.toRawAxiosRequestConfig()
    );

    const newProcess = response.data?.newProcess;
    if (newProcess) {
      this.#setProcessState(newProcess.token, newProcess.expiresAt);
    }

    return response.data;
  }

  clearAuthProcess(): void {
    this.#processID = undefined;
    this.#processExpiresAt = undefined;
  }

  // ========================================================================
  // AUTHENTICATION FLOW - SIGN UP WITH PASSKEY
  // ========================================================================
  async startSignUpWithPasskey(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    try {
      const signupData = {
        fullName: email,
        identifiers: [{ type: LoginIdentifierType.Email, identifier: email }],
      };

      const response = await this.#authApi.signupInit(
        signupData,
        metadata.toRawAxiosRequestConfig()
      );

      return response.data;
    } catch (error) {
      console.log('Sign up start error:', error);
      throw error;
    }
  }

  async finishSignUpWithPasskey(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const finishData = { signedChallenge };

    const response = await this.#authApi.passkeyAppendFinish(
      finishData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  // ========================================================================
  // AUTHENTICATION FLOW - LOGIN WITH PASSKEY
  // ========================================================================
  async startLoginWithPasskey(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const loginData = {
      identifierValue: email,
      isPhone: false,
    };

    const response = await this.#authApi.loginInit(
      loginData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  async finishLoginWithPasskey(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const finishData = { signedChallenge };

    const response = await this.#authApi.passkeyLoginFinish(
      finishData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  // ========================================================================
  // AUTHENTICATION FLOW - EMAIL OTP
  // ========================================================================
  async startLoginWithEmailOTP(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const otpStartData = {
      identifierType: LoginIdentifierType.Email,
      verificationType: VerificationMethod.EmailOtp,
    };

    const response = await this.#authApi.identifierVerifyStart(
      otpStartData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  async finishLoginWithEmailOTP(
    code: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const otpFinishData = {
      code,
      identifierType: LoginIdentifierType.Email,
      verificationType: VerificationMethod.EmailOtp,
      isNewDevice: false,
    };

    const response = await this.#authApi.identifierVerifyFinish(
      otpFinishData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  // ========================================================================
  // AUTHENTICATION FLOW - ADDITIONAL METHODS
  // ========================================================================
  async sendEmailLink(metadata: RequestMetadata): Promise<ProcessResponse> {
    const emailLinkData = {
      identifierType: LoginIdentifierType.Email,
      verificationType: VerificationMethod.EmailLink,
    };

    const response = await this.#authApi.identifierVerifyStart(
      emailLinkData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  async updateEmail(
    email: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const updateEmailData = {
      identifierType: LoginIdentifierType.Email,
      value: email,
    };

    const response = await this.#authApi.identifierUpdate(
      updateEmailData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  async finishPasskeyMediation(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const mediationData = { signedChallenge };

    const response = await this.#authApi.passkeyMediationFinish(
      mediationData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  // ========================================================================
  // PASSKEY MANAGEMENT FLOW
  // ========================================================================
  async startPasskeyAppend(
    username: string,
    fullName: string,
    metadata: RequestMetadata
  ): Promise<PasskeyAppendStartRsp> {
    const passkeyData = {
      userID: '',
      processID: '',
      username,
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
    };

    const response = await this.#passkeyApi.passkeyAppendStart(
      passkeyData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  async finishPasskeyAppend(
    signedChallenge: string,
    metadata: RequestMetadata
  ): Promise<ProcessResponse> {
    const finishData = { signedChallenge };

    const response = await this.#authApi.passkeyAppendFinish(
      finishData,
      metadata.toRawAxiosRequestConfig()
    );

    return response.data;
  }

  // ========================================================================
  // USER MANAGEMENT FLOW
  // ========================================================================
  async getFullUser(metadata: RequestMetadata): Promise<MeRsp> {
    const response = await this.#userApi.currentUserGet(
      metadata.toRawAxiosRequestConfig()
    );
    return response.data;
  }

  async updateUserWithFullName(
    fullName: string,
    metadata: RequestMetadata
  ): Promise<void> {
    const updateData = { fullName };

    await this.#userApi.currentUserUpdate(
      updateData,
      metadata.toRawAxiosRequestConfig()
    );
  }

  async deleteUser(metadata: RequestMetadata): Promise<void> {
    await this.#userApi.currentUserDelete(metadata.toRawAxiosRequestConfig());
  }

  // ========================================================================
  // PASSKEY MANAGEMENT FLOW
  // ========================================================================
  async getPasskeys(metadata: RequestMetadata): Promise<Array<Passkey>> {
    const response = await this.#userApi.currentUserPasskeyGet(
      metadata.toRawAxiosRequestConfig()
    );
    return response.data.passkeys;
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

  // ========================================================================
  // PRIVATE HELPER METHODS
  // ========================================================================
  #setProcessState(token?: string, expiresAt?: number): void {
    if (token) {
      this.#processID = token;
      // Add process ID to headers for subsequent requests
      // This would typically be done through axios interceptors or request config
      console.log('Process ID set:', token);
    }

    if (expiresAt) {
      this.#processExpiresAt = new Date(expiresAt * 1000);
      console.log('Process expires at:', this.#processExpiresAt);
    }
  }

  async #buildClientInformation(metadata: RequestMetadata) {
    return {
      remoteAddress: metadata.remoteAddress,
      userAgent: metadata.userAgent,
      userVerifyingPlatformAuthenticatorAvailable: false, // This would be determined by platform
      conditionalMediationAvailable: false, // This would be determined by platform
      parsedDeviceInfo: {
        browserName: '',
        browserVersion: '',
        osName: '',
        osVersion: '',
      },
      clientEnvHandle: undefined, // This would be retrieved from storage
    };
  }
}
