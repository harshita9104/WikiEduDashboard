import McFly from 'mcfly';
const Flux = new McFly();
import BlockStore from './block_store.js';


// Data
let _gradeables = {};
const _persisted = {};


// Utilities
const setGradeables = function (data, persisted = false) {
  for (let iw = 0; iw < data.length; iw++) {
    const week = data[iw];
    for (let ib = 0; ib < week.blocks.length; ib++) {
      const block = week.blocks[ib];
      if (block.gradeable !== undefined) {
        const { gradeable } = block;
        gradeable.order = `${iw}${block.order}`;
        _gradeables[gradeable.id] = gradeable;
        if (persisted) { _persisted[gradeable.id] = $.extend(true, {}, gradeable); }
      }
    }
  }
  return GradeableStore.emitChange();
};

const setGradeable = function (data) {
  _gradeables[data.id] = data;
  return GradeableStore.emitChange();
};

const addGradeable = function (block) {
  if (block.gradeable) {
    block.gradeable.deleted = false;
    return GradeableStore.emitChange();
  }
  return setGradeable({
    id: Date.now(),
    is_new: true,
    title: '',
    points: 10,
    gradeable_item_id: block.id,
    gradeable_item_type: 'block'
  });
};

const removeGradeable = function (gradeableId) {
  const gradeable = _gradeables[gradeableId];
  if (gradeable.is_new) {
    delete _gradeables[gradeableId];
  } else {
    gradeable.deleted = true;
  }
  return GradeableStore.emitChange();
};


// Store
const GradeableStore = Flux.createStore({
  getGradeable(gradeableId) {
    return _gradeables[gradeableId];
  },
  getGradeables() {
    let gradeable_list = [];
    let iterable = Object.keys(_gradeables);
    for (let i = 0; i < iterable.length; i++) {
      let gradeable_id = iterable[i];
      gradeable_list.push(_gradeables[gradeable_id]);
    }
    return gradeable_list;
  },
  getGradeableByBlock(block_id) {
    let iterable = Object.keys(_gradeables);
    for (let i = 0; i < iterable.length; i++) {
      let gradeable_id = iterable[i];
      if (_gradeables[gradeable_id].gradeable_item_id === block_id) {
        return _gradeables[gradeable_id];
      }
    }
  },
  restore() {
    _gradeables = $.extend(true, {}, _persisted);
    return GradeableStore.emitChange();
  }
}
, function(payload) {
  let { data } = payload;
  switch(payload.actionType) {
    case 'RECEIVE_TIMELINE': case 'SAVED_TIMELINE': case 'WIZARD_SUBMITTED':
      Flux.dispatcher.waitFor([BlockStore.dispatcherID]);
      _gradeables = {};
      setGradeables(data.course.weeks, true);
      break;
    case 'ADD_GRADEABLE':
      addGradeable(data.block);
      break;
    case 'UPDATE_GRADEABLE':
      setGradeable(data.gradeable);
      break;
    case 'DELETE_GRADEABLE':
      removeGradeable(data.gradeable_id);
      break;
  }
  return true;
});

export default GradeableStore;
