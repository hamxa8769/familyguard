// Single place where every feature module is mounted.
// Adding a feature = import its router and add one app.use() line.
import authRoutes from './modules/auth/auth.routes.js';
import consentRoutes from './modules/consent/consent.routes.js';
import devicesRoutes from './modules/devices/devices.routes.js';
import usageRoutes from './modules/usage/usage.routes.js';
import childrenRoutes from './modules/children/children.routes.js';
import screentimeRoutes from './modules/screentime/screentime.routes.js';
import appblockingRoutes from './modules/appblocking/appblocking.routes.js';
import locationRoutes from './modules/location/location.routes.js';
import geofencingRoutes from './modules/geofencing/geofencing.routes.js';
import sosRoutes from './modules/sos/sos.routes.js';
import webfilterRoutes from './modules/webfilter/webfilter.routes.js';
import bedtimeRoutes from './modules/bedtime/bedtime.routes.js';
import reportsRoutes from './modules/reports/reports.routes.js';
import transparencyRoutes from './modules/transparency/transparency.routes.js';
import commsRoutes from './modules/comms/comms.routes.js';
import filesRoutes from './modules/files/files.routes.js';
import remotecommandsRoutes from './modules/remotecommands/remotecommands.routes.js';
import mediaRoutes from './modules/media/media.routes.js';
import appsRoutes from './modules/apps/apps.routes.js';
import browsingRoutes from './modules/browsing/browsing.routes.js';
import agreementRoutes from './modules/agreement/agreement.routes.js';
import rewardsRoutes from './modules/rewards/rewards.routes.js';
import keywordsRoutes from './modules/keywords/keywords.routes.js';

export function registerRoutes(app) {
  app.use('/api/auth', authRoutes);
  app.use('/api/consent', consentRoutes);
  app.use('/api/devices', devicesRoutes);
  app.use('/api/children', childrenRoutes);
  app.use('/api/usage', usageRoutes);
  app.use('/api/screentime', screentimeRoutes);
  app.use('/api/appblocking', appblockingRoutes);
  app.use('/api/location', locationRoutes);
  app.use('/api/geofencing', geofencingRoutes);
  app.use('/api/sos', sosRoutes);
  app.use('/api/webfilter', webfilterRoutes);
  app.use('/api/bedtime', bedtimeRoutes);
  app.use('/api/reports', reportsRoutes);
  app.use('/api/transparency', transparencyRoutes);
  app.use('/api/comms', commsRoutes);
  app.use('/api/files', filesRoutes);
  app.use('/api/remotecommands', remotecommandsRoutes);
  app.use('/api/media', mediaRoutes);
  app.use('/api/apps', appsRoutes);
  app.use('/api/browsing', browsingRoutes);
  app.use('/api/agreement', agreementRoutes);
  app.use('/api/rewards', rewardsRoutes);
  app.use('/api/keywords', keywordsRoutes);
}
