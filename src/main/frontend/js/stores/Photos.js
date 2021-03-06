import { action, autorun } from 'mobx';
import Collection from './Collection';
import Uppy from '@uppy/core';
import XHRUpload from '@uppy/xhr-upload';

export default class Photos extends Collection {
  constructor(security) {
    super();
    this.security = security;
  }

  closeUppy() {
    this.uppy.close();
    this.uppy = null;
  }

  get baseApi() {
    return '/api/v1/photos';
  }

  initializeUppy() {
    this.uppy = Uppy({
      autoProceed: true,
      restrictions: {
        allowedFileTypes: ['image/*', '.jpg', '.jpeg', '.png', '.gif'],
      },
    });

    this.uppy.use(
      XHRUpload,
      {
        bundle: false,
        endpoint: '/api/v1/photos',
        fieldName: 'file',
        headers: { Authorization: `Bearer ${this.security.token}` },
        timeout: 0,
      }
    );
  }

  @action
  setData(page) {
    this.data = page.data;
  }
}
