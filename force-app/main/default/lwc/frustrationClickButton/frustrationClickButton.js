import { LightningElement, api } from 'lwc';
import scheduleInterview from '@salesforce/apex/FrustrationClickController.scheduleInterview';

export default class FrustrationClickButton extends LightningElement {
  @api recordId;
  message = '';

  handleClick() {
    this.message = 'Processing...';
    scheduleInterview({ jobAppId: this.recordId })
      .then(() => {
        this.message = 'Interview Scheduled!';
      })
      .catch(error => {
        console.error(error);
        this.message = 'Error occurred';
      });
  }
}