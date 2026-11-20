// Single place where every feature module is mounted.
// Adding a feature = import its router and add one app.use() line.
//
// API versioning (Phase 5): the existing router is mounted under BOTH
// /api and /api/v1 (dual mount, same handlers), so /api/v1/* works
// without breaking any existing client that calls /api/*.
import { requireAuth } from './middleware/auth.js';
import { me } from './modules/auth/auth.controller.js';
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
import pairingRoutes from './modules/pairing/pairing.routes.js';
import requestsRoutes from './modules/requests/requests.routes.js';
import feedRoutes from './modules/feed/feed.routes.js';

export function registerRoutes(app) {
  for (const prefix of ['/api', '/api/v1']) {
    app.get(`${prefix}/me`, requireAuth, me);
    app.use(`${prefix}/auth`, authRoutes);
    app.use(`${prefix}/consent`, consentRoutes);
    app.use(`${prefix}/devices`, devicesRoutes);
    app.use(`${prefix}/children`, childrenRoutes);
    app.use(`${prefix}/usage`, usageRoutes);
    app.use(`${prefix}/screentime`, screentimeRoutes);
    app.use(`${prefix}/appblocking`, appblockingRoutes);
    app.use(`${prefix}/location`, locationRoutes);
    app.use(`${prefix}/geofencing`, geofencingRoutes);
    app.use(`${prefix}/sos`, sosRoutes);
    app.use(`${prefix}/webfilter`, webfilterRoutes);
    app.use(`${prefix}/bedtime`, bedtimeRoutes);
    app.use(`${prefix}/reports`, reportsRoutes);
    app.use(`${prefix}/transparency`, transparencyRoutes);
    app.use(`${prefix}/comms`, commsRoutes);
    app.use(`${prefix}/files`, filesRoutes);
    app.use(`${prefix}/remotecommands`, remotecommandsRoutes);
    app.use(`${prefix}/media`, mediaRoutes);
    app.use(`${prefix}/apps`, appsRoutes);
    app.use(`${prefix}/browsing`, browsingRoutes);
    app.use(`${prefix}/agreement`, agreementRoutes);
    app.use(`${prefix}/rewards`, rewardsRoutes);
    app.use(`${prefix}/keywords`, keywordsRoutes);
    app.use(`${prefix}/pair`, pairingRoutes);
    app.use(`${prefix}/requests`, requestsRoutes);
    app.use(`${prefix}/feed`, feedRoutes);
  }
}
