part of server.src.endpoints_v1;

/// NoOp presenter used serverside to consume the [TransportAtomFactory]
class ServerPresenter extends Presenter {
  present() {}
}

/// All serverside objects use the NoOp presenter
class ServerPresenterFactory extends PresenterFactory {
  Presenter getPresenter(Message m) => new ServerPresenter();
}
