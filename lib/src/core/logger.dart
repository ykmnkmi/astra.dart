import 'request.dart';
import 'types.dart';

Application log(Application application) {
  return (Request request, Start start, Send send) {
    // TODO: implement log
    return application(request, start, send);
  };
}
