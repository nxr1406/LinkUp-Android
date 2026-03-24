import { auth } from '../firebase';
import { toast } from 'react-toastify';

export enum OperationType {
  CREATE = 'create',
  UPDATE = 'update',
  DELETE = 'delete',
  LIST = 'list',
  GET = 'get',
  WRITE = 'write',
}

export interface FirestoreErrorInfo {
  error: string;
  operationType: OperationType;
  path: string | null;
  authInfo: {
    userId?: string;
    email?: string | null;
    emailVerified?: boolean;
    isAnonymous?: boolean;
    tenantId?: string | null;
    providerInfo: {
      providerId: string;
      displayName: string | null;
      email: string | null;
      photoUrl: string | null;
    }[];
  }
}

export function handleFirestoreError(error: unknown, operationType: OperationType, path: string | null) {
  const errorMessage = error instanceof Error ? error.message : String(error);
  
  const isPermissionError = errorMessage.toLowerCase().includes('permission') || 
                            errorMessage.toLowerCase().includes('missing or insufficient permissions');
                            
  if (isPermissionError) {
    const currentUser = auth.currentUser;
    
    if (!currentUser) {
      console.warn('Firestore Permission Error while unauthenticated (likely during logout):', errorMessage);
      return;
    }

    const errInfo: FirestoreErrorInfo = {
      error: errorMessage,
      operationType,
      path,
      authInfo: {
        userId: currentUser?.uid,
        email: currentUser?.email,
        emailVerified: currentUser?.emailVerified,
        isAnonymous: currentUser?.isAnonymous,
        tenantId: currentUser?.tenantId,
        providerInfo: currentUser?.providerData.map(provider => ({
          providerId: provider.providerId,
          displayName: provider.displayName,
          email: provider.email,
          photoUrl: provider.photoURL
        })) || []
      }
    };
    
    console.error('Firestore Permission Error: ', JSON.stringify(errInfo));
    throw new Error(JSON.stringify(errInfo));
  } else if (errorMessage.includes('requires an index')) {
    console.error('Firestore Index Error: ', errorMessage);
    if (errorMessage.includes('currently building')) {
      toast.info('Database index is currently building. Please wait a moment and refresh.', { autoClose: 10000 });
    } else {
      toast.error('Database index required. Check console for details.', { autoClose: 10000 });
    }
    // Don't throw to avoid crashing the app
  } else {
    console.error('Firestore Error: ', errorMessage);
    toast.error(`Database error: ${errorMessage}`);
    // Don't throw to avoid crashing the app for other non-permission errors
  }
}
